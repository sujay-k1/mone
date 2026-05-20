import Foundation

struct AIClassificationRequest: Encodable {
    let transactionId: String
    let narration: String
    let amount: Double
    let type: String
    let mode: String
    let timestamp: String?

    let parsedCounterparty: String?
    let tokens: [String]

    let amountBand: String
    let timeBand: String?
    let dayOfMonth: Int?
    let isPaymentProcessorOnly: Bool
    let isPersonLikeCounterparty: Bool
    let hasLocalShopSignal: Bool
    let hasBillSignal: Bool
    let hasTransferSignal: Bool

    let allowedRoles: [String]
    let allowedCategoryFamilies: [String]
}

struct AIClassificationRequestBuilder {

    func build(
        transaction: RawTransaction,
        parsed: ParsedNarration,
        features: TransactionFeatures
    ) -> AIClassificationRequest {
        AIClassificationRequest(
            transactionId: transaction.id,
            narration: transaction.narration,
            amount: transaction.amount,
            type: transaction.type,
            mode: transaction.mode,
            timestamp: transaction.timestamp,
            parsedCounterparty: parsed.normalizedCounterparty,
            tokens: parsed.tokens,
            amountBand: features.amountBand,
            timeBand: features.timeBand,
            dayOfMonth: features.dayOfMonth,
            isPaymentProcessorOnly: features.isPaymentProcessorOnly,
            isPersonLikeCounterparty: features.isPersonLikeCounterparty,
            hasLocalShopSignal: features.hasLocalShopSignal,
            hasBillSignal: features.hasBillSignal,
            hasTransferSignal: features.hasTransferSignal,
            allowedRoles: MoneRole.all,
            allowedCategoryFamilies: MoneCategoryFamily.all
        )
    }
}
