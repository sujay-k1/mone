import SwiftUI
import SwiftData
import UIKit

struct LocalDatabaseDebugView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var latestPersona: StoredPersona?
    @State private var snapshots: [StoredMonthlySnapshot] = []
    @State private var accounts: [StoredAccount] = []
    @State private var reviewRows: [StoredTransactionRow] = []
    @State private var errorMessage: String?
    @State private var exportStatus: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Local DB Debug")
                        .font(.title)
                        .bold()

                    Button("Reload from DB") {
                        load()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Copy analysis JSON") {
                        copyAnalysisReport()
                    }
                    .buttonStyle(.bordered)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let exportStatus {
                        Text(exportStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let latestPersona {
                        personaSection(latestPersona)
                    } else {
                        Text("No local persona saved yet")
                            .foregroundStyle(.secondary)
                    }

                    if !accounts.isEmpty {
                        accountsSection()
                    }

                    if !snapshots.isEmpty {
                        snapshotsSection()
                    }

                    if !reviewRows.isEmpty {
                        reviewSection()
                    }
                }
                .padding()
            }
            .navigationTitle("Local DB")
            .onAppear {
                load()
            }
        }
    }

    private func personaSection(_ persona: StoredPersona) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Persona")
                .font(.headline)

            Text("ID: \(persona.id)")
            Text("Display name: \(persona.displayName)")
            Text("Source: \(persona.source)")
            Text("Last synced: \(persona.lastSyncedAt.formatted())")
        }
        .font(.caption)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func accountsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)

            ForEach(accounts) { account in
                HStack {
                    VStack(alignment: .leading) {
                        Text(account.accountType)
                            .bold()

                        Text(account.maskedAccountNumber ?? "No masked number")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let balance = account.currentBalance {
                        Text(formatCurrency(balance))
                    } else if let value = account.currentValue {
                        Text(formatCurrency(value))
                    }
                }
                .font(.caption)

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func snapshotsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Snapshots")
                .font(.headline)

            ForEach(snapshots.suffix(6)) { snapshot in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(snapshot.month)
                            .bold()

                        Spacer()

                        Text("\(snapshot.confidence)% confidence")
                            .foregroundStyle(snapshot.confidence >= 75 ? .green : .orange)
                    }

                    Text("Income: \(formatCurrency(snapshot.income))")
                    Text("Committed: \(formatCurrency(snapshot.committed))")
                    Text("Everyday: \(formatCurrency(snapshot.everyday))")
                    Text("Fund: \(formatCurrency(snapshot.fund))")
                    Text("Liability: \(formatCurrency(snapshot.liability))")
                    Text("Review: \(formatCurrency(snapshot.review))")
                    Text("Remaining: \(formatCurrency(snapshot.remaining))")
                }
                .font(.caption)

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reviewSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remaining Review Items")
                .font(.headline)

            ForEach(reviewRows.prefix(10)) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.transaction.narration)
                            .bold()

                        Spacer()

                        Text(formatCurrency(row.transaction.amount))
                    }

                    if let classification = row.classification {
                        Text("\(classification.categoryFamily) / \(classification.category)")
                        Text("Reason: \(classification.reviewReason ?? "—")")
                    }
                }
                .font(.caption)

                Divider()
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func load() {
        do {
            let store = IntelligencePersistenceStore(
                modelContext: modelContext
            )

            latestPersona = try store.loadLatestPersona()

            guard let latestPersona,
                  let personaId = PersonaId(rawValue: latestPersona.id)
            else {
                snapshots = []
                accounts = []
                reviewRows = []
                return
            }

            snapshots = try store.loadSnapshots(personaId: personaId)
            accounts = try store.loadAccounts(personaId: personaId)

            let latestMonth = snapshots.last?.month

            reviewRows = try store.loadReviewRows(
                personaId: personaId,
                month: latestMonth
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func copyAnalysisReport() {
        do {
            let store = IntelligencePersistenceStore(modelContext: modelContext)
            guard let persona = try store.loadLatestPersona(),
                  let personaId = PersonaId(rawValue: persona.id)
            else {
                exportStatus = "No local persona available to export."
                return
            }

            let snapshots = try store.loadSnapshots(personaId: personaId)
            let accounts = try store.loadAccounts(personaId: personaId)
            let rows = try store.loadTransactionRows(personaId: personaId)
            let dashboardSummary = try DashboardDataLoader(modelContext: modelContext).loadLatestSummary()
            let report = FinancialAnalysisDebugReport(
                exportedAt: ISO8601DateFormatter().string(from: Date()),
                persona: .init(persona),
                dashboardSummary: dashboardSummary.map(ReportDashboardSummary.init),
                accounts: accounts.map(ReportAccount.init),
                snapshots: snapshots.map(ReportSnapshot.init),
                goalsMonthlyInputs: makeGoalsMonthlyInputs(snapshots: snapshots, rows: rows),
                monthlyCategoryTotals: makeMonthlyCategoryTotals(rows: rows),
                transactions: rows.map(ReportTransaction.init)
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            guard let json = String(data: data, encoding: .utf8) else {
                exportStatus = "Could not encode analysis JSON."
                return
            }

            UIPasteboard.general.string = json
            exportStatus = "Copied \(rows.count) transactions, \(snapshots.count) snapshots."
        } catch {
            exportStatus = "Export failed: \(String(describing: error))"
        }
    }

    private func makeGoalsMonthlyInputs(
        snapshots: [StoredMonthlySnapshot],
        rows: [StoredTransactionRow]
    ) -> [ReportGoalsMonthlyInput] {
        let rowsByMonth = Dictionary(grouping: rows) { $0.transaction.month }

        return snapshots.map { snapshot in
            let monthRows = rowsByMonth[snapshot.month] ?? []
            let taxDeduction = monthRows
                .filter { row in
                    row.transaction.type.uppercased() == "DEBIT" &&
                    row.classification?.categoryFamily == MoneCategoryFamily.tax
                }
                .map(\.transaction.amount)
                .reduce(0, +)
            let committedNetOfTax = max(snapshot.committed - taxDeduction, 0)
            let flexibleCap = max(snapshot.income - committedNetOfTax - snapshot.fund - snapshot.liability, 0)
            let observedFlex = max(snapshot.everyday, 0) + max(snapshot.review, 0) + max(snapshot.outliers, 0)
            let rawSurplus = flexibleCap - observedFlex

            return ReportGoalsMonthlyInput(
                month: snapshot.month,
                income: snapshot.income,
                grossCommitted: snapshot.committed,
                taxDeduction: taxDeduction,
                committedNetOfTax: committedNetOfTax,
                fund: snapshot.fund,
                liability: snapshot.liability,
                flexibleCap: flexibleCap,
                everyday: snapshot.everyday,
                review: snapshot.review,
                outliers: snapshot.outliers,
                observedFlex: observedFlex,
                rawSurplus: rawSurplus,
                clampedSurplus: max(rawSurplus, 0),
                snapshotRemaining: snapshot.remaining,
                transactionCount: snapshot.transactionCount,
                reviewCount: snapshot.reviewCount,
                confidence: snapshot.confidence
            )
        }
    }

    private func makeMonthlyCategoryTotals(rows: [StoredTransactionRow]) -> [ReportMonthlyCategoryTotal] {
        let grouped = Dictionary(grouping: rows) { row in
            [
                row.transaction.month,
                row.transaction.type.uppercased(),
                row.classification?.role ?? "unclassified",
                row.classification?.categoryFamily ?? "unclassified",
                row.classification?.category ?? "unclassified"
            ].joined(separator: "||")
        }

        return grouped.map { key, rows in
            let parts = key.components(separatedBy: "||")
            return ReportMonthlyCategoryTotal(
                month: parts[safe: 0] ?? "",
                transactionType: parts[safe: 1] ?? "",
                role: parts[safe: 2] ?? "",
                categoryFamily: parts[safe: 3] ?? "",
                category: parts[safe: 4] ?? "",
                amount: rows.map(\.transaction.amount).reduce(0, +),
                count: rows.count
            )
        }
        .sorted {
            if $0.month != $1.month { return $0.month < $1.month }
            if $0.transactionType != $1.transactionType { return $0.transactionType < $1.transactionType }
            if $0.role != $1.role { return $0.role < $1.role }
            return $0.categoryFamily < $1.categoryFamily
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")

        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}
private struct FinancialAnalysisDebugReport: Codable {
    let exportedAt: String
    let persona: ReportPersona
    let dashboardSummary: ReportDashboardSummary?
    let accounts: [ReportAccount]
    let snapshots: [ReportSnapshot]
    let goalsMonthlyInputs: [ReportGoalsMonthlyInput]
    let monthlyCategoryTotals: [ReportMonthlyCategoryTotal]
    let transactions: [ReportTransaction]
}

private struct ReportPersona: Codable {
    let id: String
    let displayName: String
    let source: String
    let lastSyncedAt: String

    init(_ persona: StoredPersona) {
        id = persona.id
        displayName = persona.displayName
        source = persona.source
        lastSyncedAt = ISO8601DateFormatter().string(from: persona.lastSyncedAt)
    }
}

private struct ReportDashboardSummary: Codable {
    let month: String
    let income: Double
    let grossCommitted: Double
    let committed: Double
    let taxDeduction: Double
    let everyday: Double
    let fund: Double
    let liability: Double
    let outliers: Double
    let review: Double
    let operatingBeforeReview: Double
    let operatingRemaining: Double
    let liquidCashImpact: Double
    let safeToSpend: Double
    let liquidBalance: Double
    let confidence: Int
    let transactionCount: Int
    let reviewCount: Int
    let subscriptionAmount: Double
    let subscriptionCount: Int
    let subscriptionNames: [String]
    let totalNetWorth: Double
    let liquidNetWorth: Double
    let lockedAssets: Double

    init(_ summary: DashboardSummary) {
        month = summary.month
        income = summary.income
        grossCommitted = summary.grossCommitted
        committed = summary.committed
        taxDeduction = summary.taxDeduction
        everyday = summary.everyday
        fund = summary.fund
        liability = summary.liability
        outliers = summary.outliers
        review = summary.review
        operatingBeforeReview = summary.operatingBeforeReview
        operatingRemaining = summary.operatingRemaining
        liquidCashImpact = summary.liquidCashImpact
        safeToSpend = summary.safeToSpend
        liquidBalance = summary.liquidBalance
        confidence = summary.confidence
        transactionCount = summary.transactionCount
        reviewCount = summary.reviewCount
        subscriptionAmount = summary.subscriptionAmount
        subscriptionCount = summary.subscriptionCount
        subscriptionNames = summary.subscriptionNames
        totalNetWorth = summary.totalNetWorth
        liquidNetWorth = summary.liquidNetWorth
        lockedAssets = summary.lockedAssets
    }
}

private struct ReportAccount: Codable {
    let id: String
    let accountType: String
    let maskedAccountNumber: String?
    let currentBalance: Double?
    let currentValue: Double?

    init(_ account: StoredAccount) {
        id = account.id
        accountType = account.accountType
        maskedAccountNumber = account.maskedAccountNumber
        currentBalance = account.currentBalance
        currentValue = account.currentValue
    }
}

private struct ReportSnapshot: Codable {
    let month: String
    let income: Double
    let committed: Double
    let everyday: Double
    let fund: Double
    let liability: Double
    let outliers: Double
    let review: Double
    let remaining: Double
    let totalDebits: Double
    let classifiedDebits: Double
    let confidence: Int
    let transactionCount: Int
    let reviewCount: Int

    init(_ snapshot: StoredMonthlySnapshot) {
        month = snapshot.month
        income = snapshot.income
        committed = snapshot.committed
        everyday = snapshot.everyday
        fund = snapshot.fund
        liability = snapshot.liability
        outliers = snapshot.outliers
        review = snapshot.review
        remaining = snapshot.remaining
        totalDebits = snapshot.totalDebits
        classifiedDebits = snapshot.classifiedDebits
        confidence = snapshot.confidence
        transactionCount = snapshot.transactionCount
        reviewCount = snapshot.reviewCount
    }
}

private struct ReportGoalsMonthlyInput: Codable {
    let month: String
    let income: Double
    let grossCommitted: Double
    let taxDeduction: Double
    let committedNetOfTax: Double
    let fund: Double
    let liability: Double
    let flexibleCap: Double
    let everyday: Double
    let review: Double
    let outliers: Double
    let observedFlex: Double
    let rawSurplus: Double
    let clampedSurplus: Double
    let snapshotRemaining: Double
    let transactionCount: Int
    let reviewCount: Int
    let confidence: Int
}

private struct ReportMonthlyCategoryTotal: Codable {
    let month: String
    let transactionType: String
    let role: String
    let categoryFamily: String
    let category: String
    let amount: Double
    let count: Int
}

private struct ReportTransaction: Codable {
    let id: String
    let month: String
    let date: String?
    let timestamp: String?
    let accountId: String
    let accountType: String
    let type: String
    let mode: String
    let amount: Double
    let narration: String
    let currentBalance: Double?
    let normalizedCounterparty: String?
    let canonicalEntityName: String?
    let entityType: String?
    let role: String?
    let categoryFamily: String?
    let category: String?
    let confidence: Int?
    let needsReview: Bool?
    let reviewReason: String?
    let classificationSource: String?
    let evidence: [String]

    init(_ row: StoredTransactionRow) {
        id = row.transaction.id
        month = row.transaction.month
        date = row.transaction.valueDate
        timestamp = row.transaction.timestamp
        accountId = row.transaction.accountId
        accountType = row.transaction.accountType
        type = row.transaction.type
        mode = row.transaction.mode
        amount = row.transaction.amount
        narration = row.transaction.narration
        currentBalance = row.transaction.currentBalance
        normalizedCounterparty = row.transaction.normalizedCounterparty
        canonicalEntityName = row.classification?.canonicalEntityName
        entityType = row.classification?.entityType
        role = row.classification?.role
        categoryFamily = row.classification?.categoryFamily
        category = row.classification?.category
        confidence = row.classification?.confidence
        needsReview = row.classification?.needsReview
        reviewReason = row.classification?.reviewReason
        classificationSource = row.classification?.source
        evidence = row.classification?.evidenceText
            .split(separator: "\n")
            .map(String.init) ?? []
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

