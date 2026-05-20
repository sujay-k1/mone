import Foundation

struct TransactionFeatures {
    let amountBand: String
    let timeBand: String?
    let dayOfMonth: Int?
    let isWeekend: Bool

    let isSmallAmount: Bool
    let isMediumAmount: Bool
    let isLargeAmount: Bool
    let isVeryLargeAmount: Bool

    let isPaymentProcessorOnly: Bool
    let isPersonLikeCounterparty: Bool
    let hasMonthMarker: Bool

    let hasLocalShopSignal: Bool
    let hasBillSignal: Bool
    let hasTransferSignal: Bool

    let aiEligible: Bool
    let aiReason: String?
}
