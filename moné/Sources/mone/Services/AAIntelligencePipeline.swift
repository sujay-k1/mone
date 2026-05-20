import Foundation

struct AAIntelligenceResult {
    let personaId: PersonaId
    let importResult: ImportResult
    let snapshots: [MonthlySnapshot]
    let aiSuggestions: [String: AIClassificationSuggestion]
}

final class AAIntelligencePipeline {

    private let remotePayloadService = RemoteAAPayloadService()
    private let snapshotBuilder = MonthlySnapshotBuilder()
    private let parser = NarrationParser()
    private let classifier = TransactionClassifier()
    private let aiRequestBuilder = AIClassificationRequestBuilder()
    private let aiClient = AIReviewClassificationClient()

    func runAfterAAConsent(
        mobile: String,
        pan: String?,
        consentId: String?,
        onProgress: @escaping (DataProcessingStep) -> Void = { _ in }
    ) async throws -> AAIntelligenceResult {

        onProgress(.fetchingAccountData)

        let remoteResult = try await remotePayloadService.fetchPayload(
            mobile: mobile,
            pan: pan,
            consentId: consentId
        )

        onProgress(.readingAccounts)

        _ = remoteResult.importResult.accounts.count

        onProgress(.readingTransactions)

        _ = remoteResult.importResult.transactions.count

        onProgress(.categorisingTransactions)

        let initialSnapshots = snapshotBuilder.buildSnapshots(
            for: remoteResult.importResult
        )

        let latestMonth = initialSnapshots.last?.month

        let reviewItems = buildReviewItems(
            for: remoteResult.importResult,
            month: latestMonth
        )

        onProgress(.resolvingUnclearItems)

        let aiSuggestions: [String: AIClassificationSuggestion]

        do {
            aiSuggestions = try await fetchAISuggestionsIfNeeded(
                personaId: remoteResult.personaId,
                month: latestMonth,
                reviewItems: reviewItems
            )
        } catch {
            // AI should improve accuracy, not block onboarding.
            aiSuggestions = [:]
            print("AI suggestion failed, continuing without AI:", error)
        }

        onProgress(.buildingInsights)

        let finalSnapshots = snapshotBuilder.buildSnapshots(
            for: remoteResult.importResult,
            aiSuggestions: aiSuggestions
        )

        return AAIntelligenceResult(
            personaId: remoteResult.personaId,
            importResult: remoteResult.importResult,
            snapshots: finalSnapshots,
            aiSuggestions: aiSuggestions
        )
    }

    private func buildReviewItems(
        for result: ImportResult,
        month: String?
    ) -> [ClassifiedTransaction] {
        result.transactions
            .filter { transaction in
                transaction.accountType.lowercased() == "deposit"
            }
            .filter { transaction in
                guard let month else { return true }
                return monthKey(for: transaction) == month
            }
            .map { transaction in
                let parsed = parser.parse(transaction)

                let classification = classifier.classify(
                    transaction: transaction,
                    parsed: parsed
                )

                return ClassifiedTransaction(
                    transaction: transaction,
                    parsed: parsed,
                    classification: classification
                )
            }
            .filter { item in
                item.transaction.type.uppercased() == "DEBIT" &&
                item.classification.needsReview
            }
    }

    private func fetchAISuggestionsIfNeeded(
        personaId: PersonaId,
        month: String?,
        reviewItems: [ClassifiedTransaction]
    ) async throws -> [String: AIClassificationSuggestion] {
        guard !reviewItems.isEmpty else {
            return [:]
        }

        let requests = reviewItems.map { item in
            let features = TransactionFeatureExtractor().extract(
                transaction: item.transaction,
                parsed: item.parsed
            )

            return aiRequestBuilder.build(
                transaction: item.transaction,
                parsed: item.parsed,
                features: features
            )
        }

        let suggestions = try await aiClient.classifyReviewItems(
            personaId: personaId,
            month: month ?? "unknown",
            items: requests
        )

        return Dictionary(
            uniqueKeysWithValues: suggestions.map { ($0.transactionId, $0) }
        )
    }

    private func monthKey(for transaction: RawTransaction) -> String? {
        if let valueDate = transaction.valueDate, valueDate.count >= 7 {
            return String(valueDate.prefix(7))
        }

        if let timestamp = transaction.timestamp, timestamp.count >= 7 {
            return String(timestamp.prefix(7))
        }

        return nil
    }
}
