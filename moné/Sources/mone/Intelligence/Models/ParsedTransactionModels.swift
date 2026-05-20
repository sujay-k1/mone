import Foundation

struct ParsedNarration {
    let rawNarration: String

    let rail: String?
    let directionCode: String?
    let action: String?

    let counterpartyRaw: String?
    let normalizedCounterparty: String?

    let location: String?
    let monthMarker: String?

    let paymentProcessor: String?
    let tokens: [String]

    let isLowInformation: Bool
}
