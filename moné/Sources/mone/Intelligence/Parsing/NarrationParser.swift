import Foundation

final class NarrationParser {

    private let knownCities: Set<String> = [
        "BANGALORE",
        "BENGALURU",
        "MUMBAI",
        "DELHI",
        "NEW DELHI",
        "GURGAON",
        "GURUGRAM",
        "NOIDA",
        "PUNE",
        "HYDERABAD",
        "CHENNAI",
        "KOLKATA",
        "AHMEDABAD",
        "JAIPUR",
        "GOA"
    ]

    private let actionTokens: Set<String> = [
        "PURCHASE",
        "REDEMPTION",
        "DIVIDEND",
        "SIP",
        "TOPUP",
        "PREMIUM",
        "INTEREST",
        "MATURITY",
        "INSTALLMENT",
        "OPENING",
        "TDS",
        "CLAIM"
    ]

    private let paymentProcessorTokens: [String] = [
        "PAYTMQR",
        "PHONEPEQR",
        "BHARATPE",
        "RAZORPAY",
        "BILLDESK",
        "JUSPAY",
        "PAYU",
        "CCAVENUE",
        "CASHFREE",
        "PINE LABS",
        "MSWIPE"
    ]

    private let weakTokens: Set<String> = [
        "UPI",
        "NEFT",
        "IMPS",
        "RTGS",
        "CARD",
        "ATM",
        "NACH",
        "ACH",
        "DE",
        "CR",
        "IN",
        "OT",
        "TD",
        "OP",
        "PAYMENT",
        "TRANSFER",
        "PURCHASE",
        "TXN",
        "REF",
        "TO",
        "FROM"
    ]

    func parse(_ transaction: RawTransaction) -> ParsedNarration {
        parse(narration: transaction.narration)
    }

    func parse(narration: String) -> ParsedNarration {
        let cleanedNarration = narration.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleanedNarration
            .split(separator: "/")
            .map { String($0).trimmedUppercased() }
            .filter { !$0.isEmpty }

        let rail = parts.indices.contains(0) ? parts[0] : nil
        let directionCode = parts.indices.contains(1) ? parts[1] : nil

        var remaining = parts.count > 2 ? Array(parts.dropFirst(2)) : []

        let monthMarker = extractMonthMarker(from: &remaining)
        let location = extractLocation(from: &remaining)

        let action = extractAction(from: &remaining)

        let counterpartyRaw = buildCounterparty(from: remaining)
        let normalizedCounterparty = normalizeCounterparty(counterpartyRaw)

        let paymentProcessor = detectPaymentProcessor(in: normalizedCounterparty ?? cleanedNarration.uppercased())

        let tokens = tokenize(normalizedCounterparty)

        let isLowInformation = detectLowInformation(
            normalizedCounterparty: normalizedCounterparty,
            tokens: tokens,
            paymentProcessor: paymentProcessor
        )

        return ParsedNarration(
            rawNarration: narration,
            rail: rail,
            directionCode: directionCode,
            action: action,
            counterpartyRaw: counterpartyRaw,
            normalizedCounterparty: normalizedCounterparty,
            location: location,
            monthMarker: monthMarker,
            paymentProcessor: paymentProcessor,
            tokens: tokens,
            isLowInformation: isLowInformation
        )
    }

    private func extractMonthMarker(from parts: inout [String]) -> String? {
        guard let last = parts.last else {
            return nil
        }

        if isMonthMarker(last) {
            parts.removeLast()
            return last
        }

        return nil
    }

    private func extractLocation(from parts: inout [String]) -> String? {
        guard let last = parts.last else {
            return nil
        }

        if knownCities.contains(last) {
            parts.removeLast()
            return last
        }

        return nil
    }

    private func extractAction(from parts: inout [String]) -> String? {
        guard let first = parts.first else {
            return nil
        }

        if actionTokens.contains(first) {
            parts.removeFirst()
            return first
        }

        return nil
    }

    private func buildCounterparty(from parts: [String]) -> String? {
        let joined = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return joined.isEmpty ? nil : joined
    }

    private func normalizeCounterparty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        var normalized = value.uppercased()

        let separators = ["*", "-", "_", ".", ",", ":", ";", "|"]
        for separator in separators {
            normalized = normalized.replacingOccurrences(of: separator, with: " ")
        }

        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }

        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }

    private func tokenize(_ value: String?) -> [String] {
        guard let value else {
            return []
        }

        return value
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !weakTokens.contains($0) }
            .filter { !$0.allSatisfy(\.isNumber) }
    }

    private func detectPaymentProcessor(in value: String) -> String? {
        for token in paymentProcessorTokens {
            if value.contains(token) {
                return token
            }
        }

        return nil
    }

    private func detectLowInformation(
        normalizedCounterparty: String?,
        tokens: [String],
        paymentProcessor: String?
    ) -> Bool {
        guard let normalizedCounterparty else {
            return true
        }

        if normalizedCounterparty.isEmpty {
            return true
        }

        if let paymentProcessor {
            let counterpartyWithoutProcessor = normalizedCounterparty
                .replacingOccurrences(of: paymentProcessor, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if counterpartyWithoutProcessor.isEmpty || counterpartyWithoutProcessor.allSatisfy(\.isNumber) {
                return true
            }
        }

        if normalizedCounterparty.contains("QR") && tokens.count <= 2 {
            return true
        }

        if tokens.isEmpty {
            return true
        }

        return false
    }

    private func isMonthMarker(_ value: String) -> Bool {
        let pattern = #"^\d{4}-\d{2}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

private extension String {
    func trimmedUppercased() -> String {
        self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}
