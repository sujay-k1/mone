import Foundation
import SwiftData

// MARK: - Net Worth Data

struct NetWorthData {
    let liquid: Double
    let lockedDeposits: Double
    let investments: Double
    let liabilities: Double
    let hasNPS: Bool
    let investmentMonths: [String: Double]

    var grossAssets: Double { liquid + lockedDeposits + investments }
    var netWorth: Double { max(grossAssets - liabilities, 0) }
    var liquidityRatio: Double { grossAssets > 0 ? liquid / grossAssets : 0 }

    func emergencyFundMonths(monthlyExpense: Double) -> Double {
        guard monthlyExpense > 0 else { return 0 }
        return liquid / monthlyExpense
    }

    var investmentIsRegular: Bool {
        let sorted = investmentMonths.sorted { $0.key < $1.key }
        guard sorted.count >= 2 else { return true }
        return sorted.allSatisfy { $0.value > 0 }
    }
}

// MARK: - Category Spend Item

struct CategorySpendItem: Identifiable {
    let id = UUID()
    let categoryFamily: String
    let displayLabel: String
    let amount: Double
    let pct: Double   // fraction of total everyday spend
}

// MARK: - Savings Trend Point

struct SavingsTrendPoint: Identifiable {
    let id = UUID()
    let month: String           // "yyyy-MM"
    let monthLabel: String      // "Jan", "Feb" etc.
    let remaining: Double       // remaining bucket from snapshot
    let fund: Double            // fund_building bucket
    let liquidDelta: Double?    // net change in liquid balance (nil if unknown)
}

// MARK: - Velocity Data

struct VelocityData {
    /// Daily spend totals keyed by day-of-month (1…31). Already smoothed to 3-day rolling average.
    let current: [Int: Double]
    let previous: [Int: Double]
    let currentMonth: String
    let previousMonth: String

    /// Shared Y-axis max across both series.
    var yMax: Double {
        let allValues = Array(current.values) + Array(previous.values)
        return (allValues.max() ?? 1) * 1.15
    }

    var currentAvg: Double {
        guard !current.isEmpty else { return 0 }
        return current.values.reduce(0, +) / Double(current.count)
    }

    var previousAvg: Double {
        guard !previous.isEmpty else { return 0 }
        return previous.values.reduce(0, +) / Double(previous.count)
    }
}

@MainActor
final class DashboardDataLoader {

    private let store: IntelligencePersistenceStore

    init(modelContext: ModelContext) {
        self.store = IntelligencePersistenceStore(modelContext: modelContext)
    }

    func loadLatestSummary() throws -> DashboardSummary? {
        guard
            let persona = try store.loadLatestPersona(),
            let personaId = PersonaId(rawValue: persona.id),
            let snapshot = try store.loadLatestSnapshot(personaId: personaId)
        else {
            return nil
        }

        let accounts = try store.loadAccounts(personaId: personaId)

        let liquidBalance = accounts
            .filter { account in
                account.accountType.lowercased() == "deposit"
            }
            .compactMap(\.currentBalance)
            .reduce(0, +)

        let lockedAssets = accounts
            .filter { account in
                let type = account.accountType.lowercased()
                return type.contains("term") || (type.contains("deposit") && type != "deposit")
            }
            .compactMap(\.currentValue)
            .reduce(0, +)

        let otherAssets = accounts
            .filter { account in
                let type = account.accountType.lowercased()
                return type != "deposit" && !type.contains("term")
            }
            .compactMap { account in
                account.currentValue ?? account.currentBalance
            }
            .reduce(0, +)

        let totalNetWorth = liquidBalance + lockedAssets + otherAssets

        let taxRows = try store.loadTransactionRows(
            personaId: personaId,
            month: snapshot.month,
            categoryFamily: MoneCategoryFamily.tax
        )

        let taxDeduction = taxRows
            .filter { row in
                row.transaction.type.uppercased() == "DEBIT"
            }
            .map(\.transaction.amount)
            .reduce(0, +)

        // Current snapshot builder may still include tax inside committed outflows.
        // For dashboard clarity, separate it here so commitments mean regular obligations only.
        let regularCommitted = max(snapshot.committed - taxDeduction, 0)

        let subscriptionRows = try store.loadTransactionRows(
            personaId: personaId,
            month: snapshot.month,
            categoryFamily: MoneCategoryFamily.subscriptions
        )

        let subscriptionAmount = subscriptionRows
            .filter { row in
                row.transaction.type.uppercased() == "DEBIT"
            }
            .map(\.transaction.amount)
            .reduce(0, +)

        let subscriptionNames = subscriptionRows
            .compactMap { row in
                row.classification?.canonicalEntityName ??
                row.transaction.normalizedCounterparty ??
                row.transaction.narration
            }
            .map { cleanDisplayName($0) }
            .uniqued()
            .prefix(5)

        return DashboardSummary(
            personaId: personaId,
            displayName: persona.displayName,
            month: snapshot.month,
            income: snapshot.income,
            grossCommitted: snapshot.committed,
            committed: regularCommitted,
            taxDeduction: taxDeduction,
            everyday: snapshot.everyday,
            fund: snapshot.fund,
            liability: snapshot.liability,
            outliers: snapshot.outliers,
            review: snapshot.review,
            remaining: snapshot.remaining,
            confidence: snapshot.confidence,
            transactionCount: snapshot.transactionCount,
            reviewCount: snapshot.reviewCount,
            accountCount: accounts.count,
            liquidBalance: liquidBalance,
            subscriptionAmount: subscriptionAmount,
            subscriptionCount: subscriptionRows.count,
            subscriptionNames: Array(subscriptionNames),
            totalNetWorth: totalNetWorth,
            liquidNetWorth: liquidBalance,
            lockedAssets: lockedAssets + otherAssets
        )
    }

    func loadNetWorthData(summary: DashboardSummary) throws -> NetWorthData? {
        guard
            let persona = try store.loadLatestPersona(),
            let personaId = PersonaId(rawValue: persona.id)
        else { return nil }

        let accounts = try store.loadAccounts(personaId: personaId)

        let liquid = accounts
            .filter { $0.accountType.lowercased() == "deposit" }
            .map { $0.currentBalance ?? $0.currentValue ?? 0 }
            .reduce(0, +)

        let lockedDeposits = accounts
            .filter {
                let t = $0.accountType.lowercased()
                return t == "term_deposit" || t == "recurring_deposit"
            }
            .map { $0.currentValue ?? $0.currentBalance ?? 0 }
            .reduce(0, +)

        let investments = accounts
            .filter { $0.accountType.lowercased() == "mutual_funds" }
            .map { $0.currentValue ?? $0.currentBalance ?? 0 }
            .reduce(0, +)

        // Monthly payments × 12 approximates outstanding liability burden
        let liabilities = summary.liability * 12

        let allSnapshots = try store.loadSnapshots(personaId: personaId)
        let lastThree = allSnapshots.sorted { $0.month > $1.month }.prefix(3)
        var investmentMonths: [String: Double] = [:]
        for snap in lastThree {
            investmentMonths[snap.month] = snap.fund
        }

        return NetWorthData(
            liquid: liquid,
            lockedDeposits: lockedDeposits,
            investments: investments,
            liabilities: liabilities,
            hasNPS: false,
            investmentMonths: investmentMonths
        )
    }

    func loadSnapshots(personaId: PersonaId) throws -> [StoredMonthlySnapshot] {
        try store.loadSnapshots(personaId: personaId)
    }

    func loadReviewRows(
        personaId: PersonaId,
        month: String
    ) throws -> [StoredTransactionRow] {
        try store.loadReviewRows(
            personaId: personaId,
            month: month
        )
    }

    func loadVelocityData(currentMonth: String) throws -> VelocityData? {
        guard
            let persona = try store.loadLatestPersona(),
            let personaId = PersonaId(rawValue: persona.id)
        else { return nil }

        let previousMonth = Self.monthBefore(currentMonth)
        let todayDay = Calendar.current.component(.day, from: Date())

        // Determine if currentMonth is actually the running calendar month
        let calendarMonth = Self.calendarMonthKey(for: Date())
        let isCurrentCalendarMonth = (currentMonth == calendarMonth)

        var currentRaw  = try dailySpend(personaId: personaId, month: currentMonth)
        let previousRaw = try dailySpend(personaId: personaId, month: previousMonth)

        // Truncate current month to today so the line ends at the present day
        if isCurrentCalendarMonth {
            currentRaw = currentRaw.filter { $0.key <= todayDay }
        }

        return VelocityData(
            current: rollingAverage(currentRaw, window: 5),
            previous: rollingAverage(previousRaw, window: 5),
            currentMonth: currentMonth,
            previousMonth: previousMonth
        )
    }

    // MARK: - Velocity Helpers

    private func dailySpend(personaId: PersonaId, month: String) throws -> [Int: Double] {
        let velocityRoles: Set<String> = [
            MoneRole.everydaySpend,
            MoneRole.cashWithdrawal
        ]

        let rows = try store.loadTransactionRows(personaId: personaId, month: month)

        var totals: [Int: Double] = [:]

        for row in rows {
            let tx = row.transaction
            guard tx.type.uppercased() == "DEBIT" else { continue }

            let role = row.classification?.role ?? ""
            let isVelocityRole = velocityRoles.contains(role)

            // Outlier rule: debit ≥ ₹15,000 that isn't committed/fund/liability
            let isOutlierRole = !["committed_outflow", "fund_building", "liability_payment"].contains(role)
            let isOutlier = isOutlierRole && tx.amount >= 15_000

            guard isVelocityRole || isOutlier else { continue }

            guard let day = dayOfMonth(from: tx.valueDate ?? tx.timestamp) else { continue }
            totals[day, default: 0] += tx.amount
        }

        return totals
    }

    private func rollingAverage(_ raw: [Int: Double], window: Int) -> [Int: Double] {
        guard !raw.isEmpty else { return [:] }
        let days = raw.keys.sorted()
        var result: [Int: Double] = [:]

        for day in days {
            let windowDays = (0..<window).compactMap { offset -> Double? in
                let d = day - offset
                return raw[d]
            }
            result[day] = windowDays.reduce(0, +) / Double(windowDays.count)
        }

        return result
    }

    private func dayOfMonth(from dateString: String?) -> Int? {
        guard let s = dateString, s.count >= 10 else { return nil }
        // Format: yyyy-MM-dd
        return Int(s.dropFirst(8).prefix(2))
    }

    private static func calendarMonthKey(for date: Date) -> String {
        let cal = Calendar.current
        let year  = cal.component(.year,  from: date)
        let month = cal.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    private static func monthBefore(_ month: String) -> String {
        // month format: "yyyy-MM"
        guard
            month.count == 7,
            let year = Int(month.prefix(4)),
            let m = Int(month.suffix(2))
        else { return month }

        let prevYear  = m == 1 ? year - 1 : year
        let prevMonth = m == 1 ? 12 : m - 1
        return String(format: "%04d-%02d", prevYear, prevMonth)
    }

    private func cleanDisplayName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadTopCategories(month: String) throws -> [CategorySpendItem] {
        guard
            let persona = try store.loadLatestPersona(),
            let personaId = PersonaId(rawValue: persona.id)
        else { return [] }

        let rows = try store.loadTransactionRows(personaId: personaId, month: month)

        var totals: [String: Double] = [:]
        for row in rows {
            let tx = row.transaction
            guard tx.type.uppercased() == "DEBIT" else { continue }
            guard row.classification?.role == MoneRole.everydaySpend else { continue }
            let family = row.classification?.categoryFamily ?? "other"
            totals[family, default: 0] += tx.amount
        }

        let total = totals.values.reduce(0, +)
        guard total > 0 else { return [] }

        let sorted = totals.sorted { $0.value > $1.value }.prefix(6)

        return sorted.map { family, amount in
            let label = family
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
            return CategorySpendItem(
                categoryFamily: family,
                displayLabel: label,
                amount: amount,
                pct: amount / total
            )
        }
    }

    func loadSavingsTrend(currentMonth: String) throws -> [SavingsTrendPoint] {
        guard
            let persona = try store.loadLatestPersona(),
            let personaId = PersonaId(rawValue: persona.id)
        else { return [] }

        // Load all deposit-account transactions sorted by date ascending
        let allRows = try store.loadTransactionRows(personaId: personaId)
        let depositRows = allRows
            .filter { $0.transaction.accountType.lowercased() == "deposit" }
            .sorted {
                let a = $0.transaction.valueDate ?? $0.transaction.timestamp ?? ""
                let b = $1.transaction.valueDate ?? $1.transaction.timestamp ?? ""
                return a < b
            }

        // Group by month
        var byMonth: [String: [StoredTransactionRow]] = [:]
        for row in depositRows {
            let date = row.transaction.valueDate ?? row.transaction.timestamp ?? ""
            guard date.count >= 7 else { continue }
            let month = String(date.prefix(7))
            byMonth[month, default: []].append(row)
        }

        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        // For each month find balance just before salary credit
        var preSalaryBalances: [String: Double] = [:]
        let sortedMonths = byMonth.keys.sorted()

        for month in sortedMonths {
            let rows = byMonth[month] ?? []

            // Find salary: income-classified credit, or largest credit as fallback
            let salaryRow = rows.first { row in
                row.transaction.type.uppercased() == "CREDIT" &&
                row.classification?.role == "income"
            } ?? rows.filter { $0.transaction.type.uppercased() == "CREDIT" }
                      .max(by: { $0.transaction.amount < $1.transaction.amount })

            guard let salary = salaryRow else { continue }
            let salaryDate = salary.transaction.valueDate ?? salary.transaction.timestamp ?? ""

            // Last deposit tx strictly before the salary tx
            let before = depositRows.last {
                let d = $0.transaction.valueDate ?? $0.transaction.timestamp ?? ""
                return d < salaryDate && $0.transaction.id != salary.transaction.id
            }

            if let bal = before?.transaction.currentBalance {
                preSalaryBalances[month] = bal
            }
        }

        // Take last 12 months that have data, compute deltas
        let validMonths = sortedMonths.filter { preSalaryBalances[$0] != nil }.suffix(12)
        var points: [SavingsTrendPoint] = []
        var prevBal: Double? = nil

        for month in validMonths {
            let bal = preSalaryBalances[month]!
            let delta = prevBal.map { bal - $0 }
            let monthNum = Int(month.suffix(2)) ?? 1
            let label = monthNames[max(0, min(monthNum - 1, 11))]

            // Also pull remaining/fund from snapshot for the toggle
            let snap = (try? store.loadSnapshots(personaId: personaId))?.first { $0.month == month }

            points.append(SavingsTrendPoint(
                month: month,
                monthLabel: label,
                remaining: delta ?? 0,   // reuse remaining field for delta
                fund: snap?.fund ?? 0,
                liquidDelta: delta
            ))
            prevBal = bal
        }

        return points
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for item in self {
            let key = item.uppercased()

            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }

        return result
    }
}
