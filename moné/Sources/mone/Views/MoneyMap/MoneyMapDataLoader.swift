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

        let rows = allRows
            .filter { row in
                row.transaction.month == snapshot.month
            }
            .filter { row in
                row.transaction.type.uppercased() == "DEBIT"
            }

        let reviewRows = rows.filter { row in
            row.classification?.needsReview == true
        }

        let taxRows = rows.filter { row in
            row.classification?.categoryFamily == MoneCategoryFamily.tax
        }

        let regularCommittedRows = rows.filter { row in
            row.classification?.role == MoneRole.committedOutflow &&
            row.classification?.categoryFamily != MoneCategoryFamily.tax
        }

        let everydayRows = rows.filter { row in
            row.classification?.role == MoneRole.everydaySpend
        }

        let fundRows = rows.filter { row in
            row.classification?.role == MoneRole.fundBuilding ||
            row.classification?.categoryFamily == MoneCategoryFamily.investments
        }

        let liabilityRows = rows.filter { row in
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
            everydayGroups: categoryGroups(rows: everydayRows),
            outlierItems: outlierItems(from: rows, income: snapshot.income),
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
            MoneyMapItem(
                id: title,
                title: title,
                subtitle: "\(rows.count) transaction\(rows.count == 1 ? "" : "s")",
                amount: amount(rows),
                status: status(for: rows.first, kind: kind),
                symbolName: symbol(for: rows.first?.classification?.categoryFamily, kind: kind),
                kind: kind
            )
        }
        .sorted { $0.amount > $1.amount }
        .prefix(limit)
        .map { $0 }
    }

    private func categoryGroups(rows: [StoredTransactionRow]) -> [MoneyMapCategoryGroup] {
        let groups = Dictionary(grouping: rows) { row in
            row.classification?.categoryFamily ?? MoneCategoryFamily.other
        }

        return groups.map { family, rows in
            MoneyMapCategoryGroup(
                title: displayFamily(family),
                amount: amount(rows),
                transactionCount: rows.count,
                status: everydayStatus(amount: amount(rows), count: rows.count),
                kind: .everyday
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private func outlierItems(
        from rows: [StoredTransactionRow],
        income: Double
    ) -> [MoneyMapItem] {
        let threshold = max(20_000, income * 0.12)

        return rows
            .filter { row in
                row.transaction.amount >= threshold &&
                row.classification?.categoryFamily != MoneCategoryFamily.tax &&
                row.classification?.role != MoneRole.fundBuilding &&
                row.classification?.role != MoneRole.liabilityPayment
            }
            .sorted { $0.transaction.amount > $1.transaction.amount }
            .prefix(5)
            .map { row in
                MoneyMapItem(
                    id: row.transaction.id,
                    title: displayTitle(for: row, fallback: "Unusual outflow"),
                    subtitle: row.transaction.valueDate ?? row.transaction.timestamp ?? "One-off transaction",
                    amount: row.transaction.amount,
                    status: "Unusual",
                    symbolName: symbol(for: row.classification?.categoryFamily, kind: .outliers),
                    kind: .outliers
                )
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
                    symbolName: symbol(for: family, kind: kind),
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
        kind: MoneyMapBucketKind
    ) -> String {
        switch family {
        case MoneCategoryFamily.housing:
            return "house"
        case MoneCategoryFamily.utilities:
            return "bolt"
        case MoneCategoryFamily.familySupport:
            return "person.2"
        case MoneCategoryFamily.subscriptions:
            return "repeat"
        case MoneCategoryFamily.foodSnacks:
            return "fork.knife"
        case MoneCategoryFamily.groceries:
            return "basket"
        case MoneCategoryFamily.transport:
            return "car"
        case MoneCategoryFamily.travel:
            return "airplane"
        case MoneCategoryFamily.medical:
            return "cross.case"
        case MoneCategoryFamily.shopping:
            return "bag"
        case MoneCategoryFamily.investments:
            return "chart.line.uptrend.xyaxis"
        case MoneCategoryFamily.debt:
            return "creditcard"
        case MoneCategoryFamily.tax:
            return "doc.text"
        case MoneCategoryFamily.cash:
            return "indianrupeesign.circle"
        default:
            switch kind {
            case .fund:
                return "shield"
            case .liability:
                return "creditcard"
            case .review:
                return "questionmark.circle"
            case .outliers:
                return "exclamationmark.triangle"
            default:
                return "circle.grid.2x2"
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
