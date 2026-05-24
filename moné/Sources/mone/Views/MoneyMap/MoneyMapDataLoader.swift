import Foundation
import SwiftData

@MainActor
final class MoneyMapDataLoader {

    private let store: IntelligencePersistenceStore
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.store = IntelligencePersistenceStore(modelContext: modelContext)
    }

    func loadLatestMoneyMap() throws -> MoneyMapScreenModel? {
        guard
            let persona = try store.loadLatestPersona(),
            let personaId = PersonaId(rawValue: persona.id),
            let snapshot = try store.loadLatestSnapshot(personaId: personaId)
        else {
            return nil
        }

        let accounts = try store.loadAccounts(personaId: personaId)
        let allRows = try store.loadTransactionRows(
            personaId: personaId
        )

        let previousMonth = Self.previousMonthKey(from: snapshot.month)

        let rows = allRows
            .filter { row in
                row.transaction.month == snapshot.month
            }
            .filter { row in
                row.transaction.type.uppercased() == "DEBIT"
            }

        let previousDebitRows = allRows
            .filter { $0.transaction.month == previousMonth }
            .filter { $0.transaction.type.uppercased() == "DEBIT" }

        let reviewRows = rows.filter { row in
            row.classification?.needsReview == true
        }

        let classifiedRows = rows.filter { row in
            row.classification?.needsReview != true
        }

        let classifiedPreviousDebitRows = previousDebitRows.filter { row in
            row.classification?.needsReview != true
        }

        let taxRows = classifiedRows.filter { row in
            row.classification?.categoryFamily == MoneCategoryFamily.tax
        }

        let allCommittedRows = classifiedRows.filter { row in
            row.classification?.role == MoneRole.committedOutflow &&
            row.classification?.categoryFamily != MoneCategoryFamily.tax
        }

        let subscriptionRows = allCommittedRows.filter { row in
            row.classification?.categoryFamily == MoneCategoryFamily.subscriptions
        }

        let regularCommittedRows = allCommittedRows.filter { row in
            row.classification?.categoryFamily != MoneCategoryFamily.subscriptions
        }

        let everydayRows = classifiedRows.filter { row in
            row.classification?.role == MoneRole.everydaySpend
        }

        let fundRows = classifiedRows.filter { row in
            row.classification?.role == MoneRole.fundBuilding ||
            row.classification?.categoryFamily == MoneCategoryFamily.investments
        }

        let liabilityRows = classifiedRows.filter { row in
            row.classification?.role == MoneRole.liabilityPayment ||
            row.classification?.categoryFamily == MoneCategoryFamily.debt
        }

        let taxDeduction = amount(taxRows)
        let regularCommitted = amount(regularCommittedRows)
        let everyday = amount(everydayRows)
        let fund = amount(fundRows)
        let liability = amount(liabilityRows)
        let review = amount(reviewRows)

        let operatingRemaining = snapshot.income
            - regularCommitted
            - everyday
            - fund
            - liability
            - review

        let liquidCashImpact = operatingRemaining
            - taxDeduction
            - snapshot.outliers

        let outstandingLiabilities = accounts
            .filter { account in
                let type = account.accountType.lowercased()
                return type.contains("loan") ||
                type.contains("credit") ||
                type.contains("liabil") ||
                type.contains("debt")
            }
            .compactMap { account in
                account.currentBalance ?? account.currentValue
            }
            .map { abs($0) }
            .reduce(0, +)

        return MoneyMapScreenModel(
            personaId: personaId,
            displayName: persona.displayName,
            month: snapshot.month,
            income: snapshot.income,
            confidence: snapshot.confidence,
            transactionCount: snapshot.transactionCount,
            reviewCount: reviewRows.count,
            regularCommitted: regularCommitted,
            everyday: everyday,
            fund: fund,
            liability: liability,
            taxDeduction: taxDeduction,
            outliers: snapshot.outliers,
            review: review,
            operatingRemaining: operatingRemaining,
            liquidCashImpact: liquidCashImpact,
            outstandingLiabilities: outstandingLiabilities,
            committedItems: groupedItems(
                rows: regularCommittedRows,
                fallbackTitle: "Committed outflow",
                kind: .committed,
                limit: 8
            ),
            subscriptionItems: groupedItems(
                rows: subscriptionRows,
                fallbackTitle: "Subscription",
                kind: .committed,
                limit: 20
            ),
            everydayGroups: categoryGroups(rows: everydayRows, previousRows: classifiedPreviousDebitRows),
            outlierItems: outlierItems(from: classifiedRows, allRows: allRows, income: snapshot.income),
            fundItems: groupedItems(
                rows: fundRows,
                fallbackTitle: "Fund-building",
                kind: .fund,
                limit: 6
            ),
            liabilityItems: groupedItems(
                rows: liabilityRows,
                fallbackTitle: "Liability payment",
                kind: .liability,
                limit: 6
            ),
            reviewItems: reviewItems(from: reviewRows),
            transactions: transactionHistoryItems(from: allRows)
        )
    }



    func retagTransaction(
        transactionId: String,
        option: MoneyMapRetagOption
    ) throws {
        let descriptor = FetchDescriptor<StoredClassification>(
            predicate: #Predicate { item in
                item.transactionId == transactionId
            }
        )

        guard let classification = try modelContext.fetch(descriptor).first else {
            return
        }

        classification.role = option.role
        classification.categoryFamily = option.categoryFamily
        classification.category = option.category
        classification.confidence = 100
        classification.needsReview = false
        classification.reviewReason = nil
        classification.evidenceText = "User retagged as \(option.title)"
        classification.reviewOptionsText = ""
        classification.source = "user_override"

        try modelContext.save()
    }

    private func amount(_ rows: [StoredTransactionRow]) -> Double {
        rows.map(\.transaction.amount).reduce(0, +)
    }

    private func compactAmount(_ value: Double) -> String {
        if value >= 100_000 { return "₹\(String(format: "%.1f", value / 100_000))L" }
        if value >= 1_000   { return "₹\(String(format: "%.0f", value / 1_000))K" }
        return "₹\(Int(value))"
    }

    private func groupedItems(
        rows: [StoredTransactionRow],
        fallbackTitle: String,
        kind: MoneyMapBucketKind,
        limit: Int
    ) -> [MoneyMapItem] {
        let groups = Dictionary(grouping: rows) { row in
            displayTitle(for: row, fallback: fallbackTitle)
        }

        return groups.map { title, rows in
            let latestDate = rows
                .compactMap { $0.transaction.valueDate ?? $0.transaction.timestamp }
                .sorted()
                .last
            return MoneyMapItem(
                id: title,
                title: title,
                subtitle: "\(rows.count) transaction\(rows.count == 1 ? "" : "s")",
                amount: amount(rows),
                status: status(for: rows.first, kind: kind),
                symbolName: symbol(for: rows.first?.classification?.categoryFamily, category: rows.first?.classification?.category, title: title, kind: kind),
                kind: kind,
                dateText: latestDate
            )
        }
        .sorted { $0.amount > $1.amount }
        .prefix(limit)
        .map { $0 }
    }

    private func categoryGroups(
        rows: [StoredTransactionRow],
        previousRows: [StoredTransactionRow] = []
    ) -> [MoneyMapCategoryGroup] {
        let groups = Dictionary(grouping: rows) { row in
            row.classification?.categoryFamily ?? MoneCategoryFamily.other
        }

        // Previous month totals keyed by categoryFamily
        let prevGroups = Dictionary(grouping: previousRows) { row in
            row.classification?.categoryFamily ?? MoneCategoryFamily.other
        }

        return groups.map { family, rows in
            let total = amount(rows)

            // Daily amounts: group by day-of-month and sum
            let byDay = Dictionary(grouping: rows) { row -> Int in
                dayOfMonth(row.transaction.valueDate ?? row.transaction.timestamp)
            }
            let dailyAmounts = byDay
                .map { day, dayRows in
                    CategoryDailyAmount(id: day, day: day, amount: amount(dayRows))
                }
                .sorted { $0.day < $1.day }

            // Previous month data for this category
            let prevRows = prevGroups[family] ?? []
            let prevTotal = amount(prevRows)

            let prevByDay = Dictionary(grouping: prevRows) { row -> Int in
                dayOfMonth(row.transaction.valueDate ?? row.transaction.timestamp)
            }
            let previousMonthDailyAmounts = prevByDay
                .map { day, dayRows in
                    CategoryDailyAmount(id: day, day: day, amount: amount(dayRows))
                }
                .sorted { $0.day < $1.day }

            return MoneyMapCategoryGroup(
                title: displayFamily(family),
                amount: total,
                transactionCount: rows.count,
                status: everydayStatus(amount: total, count: rows.count),
                kind: .everyday,
                dailyAmounts: dailyAmounts,
                previousMonthDailyAmounts: previousMonthDailyAmounts,
                previousMonthAmount: prevTotal
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    /// Extracts the day-of-month integer from an ISO date string like "2025-04-15" or "2025-04-15T...".
    private func dayOfMonth(_ dateStr: String?) -> Int {
        guard let str = dateStr, str.count >= 10 else { return 1 }
        let dayStr = str.dropFirst(8).prefix(2)
        return Int(dayStr) ?? 1
    }

    /// Returns the month key for the month before `month` (format "YYYY-MM").
    private static func previousMonthKey(from month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let m = Int(parts[1]) else { return "" }
        let prevYear = m == 1 ? year - 1 : year
        let prevMonth = m == 1 ? 12 : m - 1
        return String(format: "%04d-%02d", prevYear, prevMonth)
    }

    private func outlierItems(
        from rows: [StoredTransactionRow],
        allRows: [StoredTransactionRow],
        income: Double
    ) -> [MoneyMapItem] {

        let threshold = absoluteOutlierThreshold(for: income)
        let currentMonth = rows.first?.transaction.month ?? ""

        // Build historical picture: counterparty key → [month → total amount]
        // Only DEBIT rows from past months (not current)
        let historicalDebits = allRows.filter {
            $0.transaction.type.uppercased() == "DEBIT" &&
            $0.transaction.month != currentMonth
        }

        // Counterparty key: canonical name → normalised counterparty → narration
        func cpKey(_ row: StoredTransactionRow) -> String {
            let canonical = row.classification?.canonicalEntityName ?? ""
            if !canonical.isEmpty { return canonical.uppercased() }
            let cp = row.transaction.normalizedCounterparty ?? ""
            if !cp.isEmpty { return cp.uppercased() }
            return row.transaction.narration.uppercased()
        }

        // For each counterparty: months → [rows] from history
        let historicalByCP = Dictionary(grouping: historicalDebits) { cpKey($0) }

        // Current month total per counterparty (some CPs have multiple txns this month)
        let currentByCP = Dictionary(grouping: rows) { cpKey($0) }

        var results: [MoneyMapItem] = []

        for (cp, currentTxns) in currentByCP {
            let family   = currentTxns.first?.classification?.categoryFamily ?? ""
            let role     = currentTxns.first?.classification?.role ?? ""

            // Always skip tax, fund-building, liability, self-transfer
            let skipRoles   = [MoneRole.fundBuilding, MoneRole.liabilityPayment, MoneRole.selfTransfer, MoneRole.assetTransfer]
            let skipFamilies = [MoneCategoryFamily.tax, MoneCategoryFamily.investments]
            if skipRoles.contains(role) || skipFamilies.contains(family) { continue }

            let pastMonthGroups = Dictionary(grouping: historicalByCP[cp] ?? []) { $0.transaction.month }
            let pastMonthCount  = pastMonthGroups.count
            let isRecurring     = pastMonthCount >= 2

            let currentTotal = currentTxns.map(\.transaction.amount).reduce(0, +)

            if isRecurring {
                // Rule 2 — spike: current month total > historical average × 1.05
                let pastMonthTotals = pastMonthGroups.values.map { $0.map(\.transaction.amount).reduce(0, +) }
                let historicalAvg   = pastMonthTotals.reduce(0, +) / Double(pastMonthTotals.count)

                guard historicalAvg > 0, currentTotal > historicalAvg * 1.05 else { continue }

                let spike = currentTotal - historicalAvg
                let pct   = Int(((currentTotal / historicalAvg) - 1) * 100)
                let rep   = currentTxns.first!

                results.append(MoneyMapItem(
                    id: rep.transaction.id,
                    title: displayTitle(for: rep, fallback: "Unusual spike"),
                    subtitle: "+\(pct)% vs usual · avg \(compactAmount(historicalAvg))",
                    amount: spike,
                    status: "Spike",
                    symbolName: symbol(for: family, category: rep.classification?.category, title: displayTitle(for: rep, fallback: ""), kind: .outliers),
                    kind: .outliers
                ))

            } else {
                // Rule 3 — one-off: not recurring, each individual transaction checked against threshold
                for row in currentTxns {
                    guard row.transaction.amount >= threshold else { continue }
                    results.append(MoneyMapItem(
                        id: row.transaction.id,
                        title: displayTitle(for: row, fallback: "Unusual outflow"),
                        subtitle: row.transaction.valueDate ?? row.transaction.timestamp ?? "One-off",
                        amount: row.transaction.amount,
                        status: "Unusual",
                        symbolName: symbol(for: family, category: row.classification?.category, title: displayTitle(for: row, fallback: ""), kind: .outliers),
                        kind: .outliers
                    ))
                }
            }
        }

        return results
            .sorted { $0.amount > $1.amount }
            .prefix(10)
            .map { $0 }
    }

    /// Income-bracket-based threshold for one-off outlier detection.
    private func absoluteOutlierThreshold(for income: Double) -> Double {
        switch income {
        case ..<100_000:
            // (income / 10000)% of income  →  income² / 1_000_000
            return income * income / 1_000_000
        case 100_000..<200_000:
            // (income / 25000)% of income  →  income² / 2_500_000
            return income * income / 2_500_000
        case 200_000..<300_000:
            return 20_000
        case 300_000..<400_000:
            return 30_000
        case 400_000..<1_000_000:
            return 50_000
        default:
            return 100_000
        }
    }

    private func reviewItems(from rows: [StoredTransactionRow]) -> [MoneyMapItem] {
        rows
            .sorted { $0.transaction.amount > $1.transaction.amount }
            .prefix(8)
            .map { row in
                MoneyMapItem(
                    id: row.transaction.id,
                    title: row.transaction.narration,
                    subtitle: row.classification?.reviewReason ?? "Needs confirmation",
                    amount: row.transaction.amount,
                    status: "Review",
                    symbolName: row.classification?.role == MoneRole.cashWithdrawal ? "indianrupeesign.circle" : "questionmark.circle",
                    kind: .review
                )
            }
    }



    private func transactionHistoryItems(
        from rows: [StoredTransactionRow]
    ) -> [MoneyMapTransaction] {
        rows
            .map { row in
                let kind = transactionKind(for: row)
                let family = row.classification?.categoryFamily ?? MoneCategoryFamily.other
                let category = row.classification?.category ?? "other"
                let role = row.classification?.role ?? "unknown"
                let title = displayTitle(for: row, fallback: row.transaction.type.uppercased() == "CREDIT" ? "Money received" : "Transaction")

                return MoneyMapTransaction(
                    id: row.transaction.id,
                    month: row.transaction.month,
                    dateText: displayDate(row.transaction.valueDate ?? row.transaction.timestamp),
                    sortDateText: row.transaction.valueDate ?? row.transaction.timestamp ?? row.transaction.month,
                    title: title,
                    narration: row.transaction.narration,
                    amount: row.transaction.amount,
                    type: row.transaction.type,
                    mode: row.transaction.mode,
                    accountType: row.transaction.accountType,
                    categoryFamily: family,
                    category: category,
                    role: role,
                    confidence: row.classification?.confidence ?? 0,
                    needsReview: row.classification?.needsReview ?? false,
                    reviewReason: row.classification?.reviewReason,
                    evidenceText: row.classification?.evidenceText ?? "",
                    symbolName: symbol(for: family, category: category, title: title, kind: kind),
                    kind: kind
                )
            }
            .sorted { first, second in
                first.sortDateText > second.sortDateText
            }
    }

    private func transactionKind(for row: StoredTransactionRow) -> MoneyMapBucketKind {
        if row.transaction.type.uppercased() == "CREDIT" {
            return .income
        }

        if row.classification?.needsReview == true {
            return .review
        }

        if row.classification?.categoryFamily == MoneCategoryFamily.tax {
            return .tax
        }

        if row.classification?.categoryFamily == MoneCategoryFamily.cash || row.classification?.role == MoneRole.cashWithdrawal {
            return .cash
        }

        if row.classification?.role == MoneRole.committedOutflow {
            return .committed
        }

        if row.classification?.role == MoneRole.everydaySpend {
            return .everyday
        }

        if row.classification?.role == MoneRole.fundBuilding || row.classification?.categoryFamily == MoneCategoryFamily.investments {
            return .fund
        }

        if row.classification?.role == MoneRole.liabilityPayment || row.classification?.categoryFamily == MoneCategoryFamily.debt {
            return .liability
        }

        return .neutral
    }

    private func displayDate(_ raw: String?) -> String {
        guard let raw else { return "—" }
        return String(raw.prefix(10))
    }

    private func displayTitle(
        for row: StoredTransactionRow,
        fallback: String
    ) -> String {
        if let canonical = row.classification?.canonicalEntityName, !canonical.isEmpty {
            return clean(canonical)
        }

        if let counterparty = row.transaction.normalizedCounterparty, !counterparty.isEmpty {
            return clean(counterparty)
        }

        if !row.transaction.narration.isEmpty {
            return clean(row.transaction.narration)
        }

        return fallback
    }

    private func status(
        for row: StoredTransactionRow?,
        kind: MoneyMapBucketKind
    ) -> String {
        guard let row else { return "Detected" }

        if row.classification?.needsReview == true { return "Review" }
        if row.classification?.confidence ?? 0 >= 85 { return "Confirmed" }

        switch kind {
        case .committed:
            return "Detected"
        case .fund:
            return "Set aside"
        case .liability:
            return "Paid"
        case .tax:
            return "Statutory"
        case .outliers:
            return "Unusual"
        case .review:
            return "Review"
        default:
            return "Tracked"
        }
    }

    private func everydayStatus(amount: Double, count: Int) -> String {
        if amount >= 25_000 { return "High" }
        if count >= 10 { return "Frequent" }
        return "Tracked"
    }

    private func symbol(
        for family: String?,
        category: String? = nil,
        title: String = "",
        kind: MoneyMapBucketKind
    ) -> String {
        let t = title.uppercased()
        let cat = (category ?? "").lowercased()

        switch family {

        case MoneCategoryFamily.housing:
            if t.contains("WATER") || cat.contains("water")     { return "drop.fill" }
            if t.contains("SOCIETY") || cat.contains("society") { return "building.2.fill" }
            if t.contains("MAINTENANCE") || cat.contains("maintenance") { return "wrench.and.screwdriver.fill" }
            return "house.fill"

        case MoneCategoryFamily.utilities:
            if t.contains("ELECTRICITY") || t.contains("BESCOM") || t.contains("MSEDCL") ||
               t.contains("TNEB") || t.contains("TATA POWER") || cat.contains("electricity") { return "bolt.fill" }
            if t.contains("GAS") || t.contains("LPG") || t.contains("PNG") ||
               t.contains("INDANE") || t.contains("HP GAS") || t.contains("BHARAT GAS") ||
               cat.contains("gas") || cat.contains("lpg")                { return "flame.fill" }
            if t.contains("MOBILE") || t.contains("AIRTEL") || t.contains("JIO") ||
               t.contains("BSNL") || t.contains("VODAFONE") || t.contains("VI ") ||
               cat.contains("mobile") || cat.contains("phone")           { return "iphone" }
            if t.contains("BROADBAND") || t.contains("FIBER") || t.contains("FIBRE") ||
               t.contains("INTERNET") || t.contains("ACT ") || t.contains("HATHWAY") ||
               cat.contains("internet") || cat.contains("broadband")     { return "wifi" }
            if t.contains("WATER") || cat.contains("water")              { return "drop.fill" }
            return "bolt.fill"

        case MoneCategoryFamily.familySupport:
            return "person.2.fill"

        case MoneCategoryFamily.householdHelp:
            return "hands.and.sparkles.fill"

        case MoneCategoryFamily.subscriptions:
            // Per-service icons for subscription mini-cards
            if t.contains("NETFLIX")                                      { return "play.rectangle.fill" }
            if t.contains("SPOTIFY")                                      { return "music.note" }
            if t.contains("APPLE") || t.contains("ICLOUD")               { return "applelogo" }
            if t.contains("AMAZON") || t.contains("PRIME")               { return "shippingbox.fill" }
            if t.contains("YOUTUBE") || t.contains("GOOGLE")             { return "play.circle.fill" }
            if t.contains("HOTSTAR") || t.contains("DISNEY")             { return "sparkles.tv.fill" }
            if t.contains("TRUECALLER")                                   { return "phone.circle.fill" }
            if t.contains("LINKEDIN")                                     { return "person.crop.rectangle.stack.fill" }
            if t.contains("GYM") || t.contains("FITNESS") || t.contains("CULT") { return "dumbbell.fill" }
            if t.contains("ADOBE")                                        { return "paintbrush.fill" }
            return "repeat"

        case MoneCategoryFamily.creditCard:
            return "creditcard.fill"

        case MoneCategoryFamily.foodSnacks:
            if t.contains("SWIGGY") || t.contains("ZOMATO") || t.contains("DELIVERY") { return "bicycle" }
            return "fork.knife"

        case MoneCategoryFamily.groceries:
            if t.contains("BLINKIT") || t.contains("ZEPTO") || t.contains("DUNZO") { return "cart.fill" }
            return "basket.fill"

        case MoneCategoryFamily.transport:
            if t.contains("METRO")                                        { return "tram.fill" }
            if t.contains("UBER") || t.contains("OLA") || t.contains("RAPIDO") { return "car.fill" }
            if t.contains("PETROL") || t.contains("FUEL") || t.contains("HPCL") ||
               t.contains("IOCL") || t.contains("BPCL")                  { return "fuelpump.fill" }
            if t.contains("PARKING")                                      { return "parkingsign" }
            return "car.fill"

        case MoneCategoryFamily.travel:
            if t.contains("HOTEL") || t.contains("STAY") || t.contains("OYO") { return "bed.double.fill" }
            if t.contains("FLIGHT") || t.contains("AIRLINE") || t.contains("AIR ") { return "airplane" }
            if t.contains("IRCTC") || t.contains("TRAIN")                { return "tram.fill" }
            return "airplane"

        case MoneCategoryFamily.medical:
            if t.contains("PHARMACY") || t.contains("MEDPLUS") || t.contains("APOLLO PHARMACY") ||
               t.contains("1MG") || t.contains("NETMEDS")                { return "pills.fill" }
            if t.contains("LAB") || t.contains("DIAGNOSTIC") || t.contains("TEST") { return "waveform.path.ecg" }
            return "cross.case.fill"

        case MoneCategoryFamily.shopping:
            if t.contains("AMAZON")                                       { return "shippingbox.fill" }
            if t.contains("FLIPKART") || t.contains("MEESHO")            { return "cart.fill" }
            if t.contains("MYNTRA") || t.contains("AJIO") || t.contains("NYKAA") { return "tshirt.fill" }
            return "bag.fill"

        case MoneCategoryFamily.investments:
            if t.contains("MUTUAL") || t.contains("MF") || t.contains("ZERODHA") ||
               t.contains("GROWW") || t.contains("COIN")                 { return "chart.pie.fill" }
            if t.contains("GOLD")                                         { return "circle.fill" }
            if t.contains("FD") || t.contains("FIXED DEPOSIT")           { return "lock.fill" }
            if t.contains("NPS")                                          { return "person.badge.clock.fill" }
            return "chart.line.uptrend.xyaxis"

        case MoneCategoryFamily.debt:
            if t.contains("HOME LOAN") || cat.contains("home_loan")      { return "house.circle.fill" }
            if t.contains("EDUCATION") || cat.contains("education_loan") { return "graduationcap.fill" }
            if t.contains("CAR LOAN") || t.contains("AUTO LOAN")         { return "car.circle.fill" }
            return "banknote.fill"

        case MoneCategoryFamily.tax:
            return "building.columns.fill"

        case MoneCategoryFamily.cash:
            return "indianrupeesign.circle.fill"

        case MoneCategoryFamily.insurance:
            if t.contains("HEALTH") || t.contains("MEDICAL")             { return "cross.circle.fill" }
            if t.contains("LIFE") || t.contains("LIC")                   { return "heart.circle.fill" }
            if t.contains("CAR") || t.contains("VEHICLE")                { return "car.circle.fill" }
            return "shield.fill"

        case MoneCategoryFamily.education:
            if t.contains("SCHOOL") || t.contains("TUITION")             { return "pencil.and.ruler.fill" }
            if t.contains("COURSE") || t.contains("UDEMY") || t.contains("COURSERA") { return "play.square.stack.fill" }
            return "graduationcap.fill"

        case MoneCategoryFamily.personalCare:
            return "sparkles"

        case MoneCategoryFamily.lifestyleEntertainment:
            if t.contains("CINEMA") || t.contains("MOVIE") || t.contains("PVR") ||
               t.contains("INOX")                                         { return "film.fill" }
            return "party.popper.fill"

        case MoneCategoryFamily.giftsDonations:
            if t.contains("DONAT") || t.contains("NGO") || t.contains("CHARITY") { return "hands.holding.heart.fill" }
            return "gift.fill"

        default:
            switch kind {
            case .fund:      return "shield.fill"
            case .liability: return "banknote.fill"
            case .review:    return "questionmark.circle.fill"
            case .outliers:  return "exclamationmark.triangle.fill"
            default:         return "circle.grid.2x2.fill"
            }
        }
    }

    private func displayFamily(_ family: String) -> String {
        family
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(4)
            .joined(separator: " ")
    }
}
