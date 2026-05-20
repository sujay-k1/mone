import Foundation
import SwiftData

@MainActor
final class IntelligencePersistenceStore {

    private let modelContext: ModelContext

    private let parser = NarrationParser()
    private let classifier = TransactionClassifier()
    private let overrideResolver = ClassificationOverrideResolver()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ result: AAIntelligenceResult) throws {
        let personaId = result.personaId.rawValue
        let now = Date()

        try deleteExistingData(for: personaId)
        try modelContext.save()

        let persona = StoredPersona(
            id: personaId,
            displayName: personaId.capitalized,
            lastSyncedAt: now,
            source: "mock_account_aggregator"
        )

        modelContext.insert(persona)

        for account in result.importResult.accounts {
            let storedAccount = StoredAccount(
                id: account.id,
                personaId: personaId,
                fipId: account.fipId,
                accountType: account.accountType,
                maskedAccountNumber: account.maskedAccountNumber,
                currentBalance: account.currentBalance,
                currentValue: account.currentValue,
                lastUpdatedAt: now
            )

            modelContext.insert(storedAccount)
        }

        for transaction in result.importResult.transactions {
            let parsed = parser.parse(transaction)

            let baseClassification = classifier.classify(
                transaction: transaction,
                parsed: parsed
            )

            let effectiveClassification = overrideResolver.resolve(
                base: baseClassification,
                aiSuggestion: result.aiSuggestions[transaction.id]
            )

            let month = monthKey(for: transaction)

            let storedTransaction = StoredTransaction(
                id: transaction.id,
                personaId: personaId,
                accountId: transaction.accountId,
                accountType: transaction.accountType,
                type: transaction.type,
                mode: transaction.mode,
                amount: transaction.amount,
                narration: transaction.narration,
                valueDate: transaction.valueDate,
                timestamp: transaction.timestamp,
                month: month,
                currentBalance: transaction.currentBalance,
                normalizedCounterparty: parsed.normalizedCounterparty,
                createdAt: now
            )

            modelContext.insert(storedTransaction)

            let storedClassification = StoredClassification(
                id: "classification_\(transaction.id)",
                transactionId: transaction.id,
                personaId: personaId,
                month: month,
                canonicalEntityName: effectiveClassification.canonicalEntityName,
                entityType: effectiveClassification.entityType,
                role: effectiveClassification.role,
                categoryFamily: effectiveClassification.categoryFamily,
                category: effectiveClassification.category,
                confidence: effectiveClassification.confidence,
                needsReview: effectiveClassification.needsReview,
                reviewReason: effectiveClassification.reviewReason,
                evidenceText: effectiveClassification.evidence.joined(separator: "\n"),
                reviewOptionsText: effectiveClassification.reviewOptions.joined(separator: "\n"),
                source: result.aiSuggestions[transaction.id] == nil ? "on_device" : "ai_resolved",
                createdAt: now
            )

            modelContext.insert(storedClassification)
        }

        for suggestion in result.aiSuggestions.values {
            let month = monthForTransactionId(
                suggestion.transactionId,
                from: result.importResult.transactions
            )

            let storedSuggestion = StoredAISuggestion(
                id: "ai_\(suggestion.transactionId)",
                transactionId: suggestion.transactionId,
                personaId: personaId,
                month: month,
                role: suggestion.role,
                categoryFamily: suggestion.categoryFamily,
                category: suggestion.category,
                confidence: suggestion.confidence,
                needsReview: suggestion.needsReview,
                reviewQuestion: suggestion.reviewQuestion,
                evidenceText: suggestion.evidence.joined(separator: "\n"),
                createdAt: now
            )

            modelContext.insert(storedSuggestion)
        }

        for snapshot in result.snapshots {
            let storedSnapshot = StoredMonthlySnapshot(
                id: snapshot.id,
                personaId: personaId,
                month: snapshot.month,
                income: snapshot.income,
                committed: snapshot.committed,
                everyday: snapshot.everyday,
                fund: snapshot.fund,
                liability: snapshot.liability,
                outliers: snapshot.outliers,
                review: snapshot.review,
                remaining: snapshot.remaining,
                totalDebits: snapshot.totalDebits,
                classifiedDebits: snapshot.classifiedDebits,
                confidence: snapshot.confidence,
                transactionCount: snapshot.transactionCount,
                reviewCount: snapshot.reviewCount,
                createdAt: now
            )

            modelContext.insert(storedSnapshot)
        }

        try modelContext.save()
    }

    func loadLatestPersona() throws -> StoredPersona? {
        var descriptor = FetchDescriptor<StoredPersona>(
            sortBy: [
                SortDescriptor(\.lastSyncedAt, order: .reverse)
            ]
        )

        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    func loadSnapshots(
        personaId: PersonaId
    ) throws -> [StoredMonthlySnapshot] {
        let id = personaId.rawValue

        let descriptor = FetchDescriptor<StoredMonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.personaId == id
            },
            sortBy: [
                SortDescriptor(\.month)
            ]
        )

        return try modelContext.fetch(descriptor)
    }

    func loadLatestSnapshot(
        personaId: PersonaId
    ) throws -> StoredMonthlySnapshot? {
        let id = personaId.rawValue

        var descriptor = FetchDescriptor<StoredMonthlySnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.personaId == id
            },
            sortBy: [
                SortDescriptor(\.month, order: .reverse)
            ]
        )

        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    func loadTransactionRows(
        personaId: PersonaId,
        month: String? = nil,
        categoryFamily: String? = nil,
        role: String? = nil,
        needsReview: Bool? = nil
    ) throws -> [StoredTransactionRow] {
        let id = personaId.rawValue

        let transactionDescriptor = FetchDescriptor<StoredTransaction>(
            predicate: #Predicate { transaction in
                transaction.personaId == id
            },
            sortBy: [
                SortDescriptor(\.valueDate),
                SortDescriptor(\.timestamp)
            ]
        )

        let classificationDescriptor = FetchDescriptor<StoredClassification>(
            predicate: #Predicate { classification in
                classification.personaId == id
            }
        )

        let transactions = try modelContext.fetch(transactionDescriptor)
        let classifications = try modelContext.fetch(classificationDescriptor)

        let classificationByTransactionId = Dictionary(
            uniqueKeysWithValues: classifications.map { ($0.transactionId, $0) }
        )

        return transactions
            .compactMap { transaction in
                let classification = classificationByTransactionId[transaction.id]

                if let month, transaction.month != month {
                    return nil
                }

                if let categoryFamily,
                   classification?.categoryFamily != categoryFamily {
                    return nil
                }

                if let role,
                   classification?.role != role {
                    return nil
                }

                if let needsReview,
                   classification?.needsReview != needsReview {
                    return nil
                }

                return StoredTransactionRow(
                    transaction: transaction,
                    classification: classification
                )
            }
    }

    func loadReviewRows(
        personaId: PersonaId,
        month: String? = nil
    ) throws -> [StoredTransactionRow] {
        try loadTransactionRows(
            personaId: personaId,
            month: month,
            needsReview: true
        )
        .sorted { first, second in
            first.transaction.amount > second.transaction.amount
        }
    }

    func loadAccounts(
        personaId: PersonaId
    ) throws -> [StoredAccount] {
        let id = personaId.rawValue

        let descriptor = FetchDescriptor<StoredAccount>(
            predicate: #Predicate { account in
                account.personaId == id
            },
            sortBy: [
                SortDescriptor(\.accountType)
            ]
        )

        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Cloud backup export / restore

    func exportLatestBackup() throws -> FinancialDataBackupPayload? {
        guard let persona = try loadLatestPersona() else {
            return nil
        }

        let personaId = persona.id

        let accountDescriptor = FetchDescriptor<StoredAccount>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        let transactionDescriptor = FetchDescriptor<StoredTransaction>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        let classificationDescriptor = FetchDescriptor<StoredClassification>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        let aiSuggestionDescriptor = FetchDescriptor<StoredAISuggestion>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        let snapshotDescriptor = FetchDescriptor<StoredMonthlySnapshot>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        let accounts = try modelContext.fetch(accountDescriptor)
        let transactions = try modelContext.fetch(transactionDescriptor)
        let classifications = try modelContext.fetch(classificationDescriptor)
        let aiSuggestions = try modelContext.fetch(aiSuggestionDescriptor)
        let snapshots = try modelContext.fetch(snapshotDescriptor)

        return FinancialDataBackupPayload(
            dataVersion: "v1",
            backedUpAt: Self.isoString(Date()),
            persona: PersonaBackup(
                id: persona.id,
                displayName: persona.displayName,
                lastSyncedAt: Self.isoString(persona.lastSyncedAt),
                source: persona.source
            ),
            accounts: accounts.map {
                AccountBackup(
                    id: $0.id,
                    personaId: $0.personaId,
                    fipId: $0.fipId,
                    accountType: $0.accountType,
                    maskedAccountNumber: $0.maskedAccountNumber,
                    currentBalance: $0.currentBalance,
                    currentValue: $0.currentValue,
                    lastUpdatedAt: Self.isoString($0.lastUpdatedAt)
                )
            },
            transactions: transactions.map {
                TransactionBackup(
                    id: $0.id,
                    personaId: $0.personaId,
                    accountId: $0.accountId,
                    accountType: $0.accountType,
                    type: $0.type,
                    mode: $0.mode,
                    amount: $0.amount,
                    narration: $0.narration,
                    valueDate: $0.valueDate,
                    timestamp: $0.timestamp,
                    month: $0.month,
                    currentBalance: $0.currentBalance,
                    normalizedCounterparty: $0.normalizedCounterparty,
                    createdAt: Self.isoString($0.createdAt)
                )
            },
            classifications: classifications.map {
                ClassificationBackup(
                    id: $0.id,
                    transactionId: $0.transactionId,
                    personaId: $0.personaId,
                    month: $0.month,
                    canonicalEntityName: $0.canonicalEntityName,
                    entityType: $0.entityType,
                    role: $0.role,
                    categoryFamily: $0.categoryFamily,
                    category: $0.category,
                    confidence: $0.confidence,
                    needsReview: $0.needsReview,
                    reviewReason: $0.reviewReason,
                    evidenceText: $0.evidenceText,
                    reviewOptionsText: $0.reviewOptionsText,
                    source: $0.source,
                    createdAt: Self.isoString($0.createdAt)
                )
            },
            aiSuggestions: aiSuggestions.map {
                AISuggestionBackup(
                    id: $0.id,
                    transactionId: $0.transactionId,
                    personaId: $0.personaId,
                    month: $0.month,
                    role: $0.role,
                    categoryFamily: $0.categoryFamily,
                    category: $0.category,
                    confidence: $0.confidence,
                    needsReview: $0.needsReview,
                    reviewQuestion: $0.reviewQuestion,
                    evidenceText: $0.evidenceText,
                    createdAt: Self.isoString($0.createdAt)
                )
            },
            monthlySnapshots: snapshots.map {
                MonthlySnapshotBackup(
                    id: $0.id,
                    personaId: $0.personaId,
                    month: $0.month,
                    income: $0.income,
                    committed: $0.committed,
                    everyday: $0.everyday,
                    fund: $0.fund,
                    liability: $0.liability,
                    outliers: $0.outliers,
                    review: $0.review,
                    remaining: $0.remaining,
                    totalDebits: $0.totalDebits,
                    classifiedDebits: $0.classifiedDebits,
                    confidence: $0.confidence,
                    transactionCount: $0.transactionCount,
                    reviewCount: $0.reviewCount,
                    createdAt: Self.isoString($0.createdAt)
                )
            }
        )
    }

    func restore(from backup: FinancialDataBackupPayload) throws {
        let personaId = backup.persona.id

        try deleteExistingData(for: personaId)
        try modelContext.save()

        modelContext.insert(
            StoredPersona(
                id: backup.persona.id,
                displayName: backup.persona.displayName,
                lastSyncedAt: Self.date(from: backup.persona.lastSyncedAt),
                source: backup.persona.source
            )
        )

        for account in backup.accounts {
            modelContext.insert(
                StoredAccount(
                    id: account.id,
                    personaId: account.personaId,
                    fipId: account.fipId,
                    accountType: account.accountType,
                    maskedAccountNumber: account.maskedAccountNumber,
                    currentBalance: account.currentBalance,
                    currentValue: account.currentValue,
                    lastUpdatedAt: Self.date(from: account.lastUpdatedAt)
                )
            )
        }

        for transaction in backup.transactions {
            modelContext.insert(
                StoredTransaction(
                    id: transaction.id,
                    personaId: transaction.personaId,
                    accountId: transaction.accountId,
                    accountType: transaction.accountType,
                    type: transaction.type,
                    mode: transaction.mode,
                    amount: transaction.amount,
                    narration: transaction.narration,
                    valueDate: transaction.valueDate,
                    timestamp: transaction.timestamp,
                    month: transaction.month,
                    currentBalance: transaction.currentBalance,
                    normalizedCounterparty: transaction.normalizedCounterparty,
                    createdAt: Self.date(from: transaction.createdAt)
                )
            )
        }

        for classification in backup.classifications {
            modelContext.insert(
                StoredClassification(
                    id: classification.id,
                    transactionId: classification.transactionId,
                    personaId: classification.personaId,
                    month: classification.month,
                    canonicalEntityName: classification.canonicalEntityName,
                    entityType: classification.entityType,
                    role: classification.role,
                    categoryFamily: classification.categoryFamily,
                    category: classification.category,
                    confidence: classification.confidence,
                    needsReview: classification.needsReview,
                    reviewReason: classification.reviewReason,
                    evidenceText: classification.evidenceText,
                    reviewOptionsText: classification.reviewOptionsText,
                    source: classification.source,
                    createdAt: Self.date(from: classification.createdAt)
                )
            )
        }

        for suggestion in backup.aiSuggestions {
            modelContext.insert(
                StoredAISuggestion(
                    id: suggestion.id,
                    transactionId: suggestion.transactionId,
                    personaId: suggestion.personaId,
                    month: suggestion.month,
                    role: suggestion.role,
                    categoryFamily: suggestion.categoryFamily,
                    category: suggestion.category,
                    confidence: suggestion.confidence,
                    needsReview: suggestion.needsReview,
                    reviewQuestion: suggestion.reviewQuestion,
                    evidenceText: suggestion.evidenceText,
                    createdAt: Self.date(from: suggestion.createdAt)
                )
            )
        }

        for snapshot in backup.monthlySnapshots {
            modelContext.insert(
                StoredMonthlySnapshot(
                    id: snapshot.id,
                    personaId: snapshot.personaId,
                    month: snapshot.month,
                    income: snapshot.income,
                    committed: snapshot.committed,
                    everyday: snapshot.everyday,
                    fund: snapshot.fund,
                    liability: snapshot.liability,
                    outliers: snapshot.outliers,
                    review: snapshot.review,
                    remaining: snapshot.remaining,
                    totalDebits: snapshot.totalDebits,
                    classifiedDebits: snapshot.classifiedDebits,
                    confidence: snapshot.confidence,
                    transactionCount: snapshot.transactionCount,
                    reviewCount: snapshot.reviewCount,
                    createdAt: Self.date(from: snapshot.createdAt)
                )
            )
        }

        try modelContext.save()
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func date(from value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date()
    }

    // MARK: - Delete existing persona data

    private func deleteExistingData(for personaId: String) throws {
        try deletePersonas(for: personaId)
        try deleteAccounts(for: personaId)
        try deleteTransactions(for: personaId)
        try deleteClassifications(for: personaId)
        try deleteAISuggestions(for: personaId)
        try deleteMonthlySnapshots(for: personaId)
    }

    private func deletePersonas(for personaId: String) throws {
        let descriptor = FetchDescriptor<StoredPersona>(
            predicate: #Predicate { item in
                item.id == personaId
            }
        )

        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
    }

    private func deleteAccounts(for personaId: String) throws {
        let descriptor = FetchDescriptor<StoredAccount>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
    }

    private func deleteTransactions(for personaId: String) throws {
        let descriptor = FetchDescriptor<StoredTransaction>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
    }

    private func deleteClassifications(for personaId: String) throws {
        let descriptor = FetchDescriptor<StoredClassification>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
    }

    private func deleteAISuggestions(for personaId: String) throws {
        let descriptor = FetchDescriptor<StoredAISuggestion>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
    }

    private func deleteMonthlySnapshots(for personaId: String) throws {
        let descriptor = FetchDescriptor<StoredMonthlySnapshot>(
            predicate: #Predicate { item in
                item.personaId == personaId
            }
        )

        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
    }

    // MARK: - Helpers

    private func monthKey(for transaction: RawTransaction) -> String {
        if let valueDate = transaction.valueDate, valueDate.count >= 7 {
            return String(valueDate.prefix(7))
        }

        if let timestamp = transaction.timestamp, timestamp.count >= 7 {
            return String(timestamp.prefix(7))
        }

        return "unknown"
    }

    private func monthForTransactionId(
        _ transactionId: String,
        from transactions: [RawTransaction]
    ) -> String {
        guard let transaction = transactions.first(where: { $0.id == transactionId }) else {
            return "unknown"
        }

        return monthKey(for: transaction)
    }
}
