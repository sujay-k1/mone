import Foundation
import SwiftData

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

    private func cleanDisplayName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
