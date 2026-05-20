import Foundation

final class TransactionFeatureExtractor {

    func extract(
        transaction: RawTransaction,
        parsed: ParsedNarration
    ) -> TransactionFeatures {

        let amount = transaction.amount
        let amountBand = amountBand(for: amount)

        let date = parseDate(transaction.timestamp) ?? parseDate(transaction.valueDate)
        let calendar = Calendar.current

        let hour: Int?
        let weekday: Int?
        let dayOfMonth: Int?

        if let date {
            hour = calendar.component(.hour, from: date)
            weekday = calendar.component(.weekday, from: date)
            dayOfMonth = calendar.component(.day, from: date)
        } else {
            hour = nil
            weekday = nil
            dayOfMonth = nil
        }

        let resolvedTimeBand: String?
        if let hour {
            resolvedTimeBand = timeBandName(for: hour)
        } else {
            resolvedTimeBand = nil
        }

        let isWeekend = {
            guard let weekday else { return false }
            return weekday == 1 || weekday == 7
        }()

        let text = parsed.normalizedCounterparty ?? ""
        let tokens = parsed.tokens

        let isPaymentProcessorOnly =
            parsed.paymentProcessor != nil &&
            parsed.isLowInformation

        let isPersonLikeCounterparty = detectPersonLikeCounterparty(
            text: text,
            tokens: tokens,
            transaction: transaction
        )

        let hasLocalShopSignal = detectLocalShopSignal(text: text)
        let hasBillSignal = detectBillSignal(text: text)
        let hasTransferSignal = detectTransferSignal(text: text, transaction: transaction)

        let aiEligibility = determineAIEligibility(
            transaction: transaction,
            parsed: parsed,
            isPaymentProcessorOnly: isPaymentProcessorOnly,
            isPersonLikeCounterparty: isPersonLikeCounterparty
        )

        return TransactionFeatures(
            amountBand: amountBand,
            timeBand: resolvedTimeBand,
            dayOfMonth: dayOfMonth,
            isWeekend: isWeekend,
            isSmallAmount: amount < 500,
            isMediumAmount: amount >= 500 && amount < 5_000,
            isLargeAmount: amount >= 5_000 && amount < 50_000,
            isVeryLargeAmount: amount >= 50_000,
            isPaymentProcessorOnly: isPaymentProcessorOnly,
            isPersonLikeCounterparty: isPersonLikeCounterparty,
            hasMonthMarker: parsed.monthMarker != nil,
            hasLocalShopSignal: hasLocalShopSignal,
            hasBillSignal: hasBillSignal,
            hasTransferSignal: hasTransferSignal,
            aiEligible: aiEligibility.isEligible,
            aiReason: aiEligibility.reason
        )
    }

    private func amountBand(for amount: Double) -> String {
        switch amount {
        case 0..<100:
            return "tiny"
        case 100..<500:
            return "small"
        case 500..<2_000:
            return "medium"
        case 2_000..<10_000:
            return "large"
        case 10_000..<50_000:
            return "very_large"
        default:
            return "exceptional"
        }
    }

    private func timeBandName(for hour: Int) -> String {
        switch hour {
        case 5..<11:
            return "morning"
        case 11..<16:
            return "afternoon"
        case 16..<20:
            return "evening"
        default:
            return "night"
        }
    }

    private func detectPersonLikeCounterparty(
        text: String,
        tokens: [String],
        transaction: RawTransaction
    ) -> Bool {
        guard transaction.type.uppercased() == "DEBIT" else {
            return false
        }

        let knownNonPersonWords: Set<String> = [
            "SHOP", "STORE", "STORES", "MART", "BILL", "PAYMENT",
            "FUND", "BANK", "LOAN", "CARD", "MOBILE", "ELECTRICITY",
            "PHARMACY", "MEDICAL", "CLINIC", "RENT", "LANDLORD",
            "FIBERNET", "PREMIUM", "SUBSCRIPTION", "TRANSFER"
        ]

        if tokens.isEmpty {
            return false
        }

        if tokens.contains(where: { knownNonPersonWords.contains($0) }) {
            return false
        }

        if text.contains("PAPA") ||
            text.contains("MOM") ||
            text.contains("ROHAN") ||
            text.contains("NEHA") ||
            text.contains("SURESH") ||
            text.contains("ANIKET") {
            return true
        }

        return tokens.count <= 2 &&
            transaction.mode.uppercased() != "CARD" &&
            tokens.allSatisfy { token in
                token.count >= 3 &&
                token.allSatisfy { $0.isLetter }
            }
    }

    private func detectLocalShopSignal(text: String) -> Bool {
        let localSignals = [
            "SHOP", "STORE", "STORES", "MART", "CENTER", "CENTRE",
            "BAKERY", "CHAAT", "MOMO", "JUICE", "FLOWER",
            "XEROX", "PRINT", "STATIONERY", "KIRANA",
            "PAAN", "PAN SHOP", "CIGARETTE"
        ]

        return localSignals.contains { text.contains($0) }
    }

    private func detectBillSignal(text: String) -> Bool {
        let billSignals = [
            "BILL", "ELECTRICITY", "MOBILE", "FIBERNET",
            "BROADBAND", "LPG", "GAS", "MAINTENANCE",
            "PREMIUM", "EMI", "LOAN"
        ]

        return billSignals.contains { text.contains($0) }
    }

    private func detectTransferSignal(
        text: String,
        transaction: RawTransaction
    ) -> Bool {
        if transaction.mode.uppercased() == "FT" {
            return true
        }

        return text.contains("TRANSFER") ||
            text.contains("SBI") ||
            text.contains("ICICI") ||
            text.contains("HDFC")
    }

    private func determineAIEligibility(
        transaction: RawTransaction,
        parsed: ParsedNarration,
        isPaymentProcessorOnly: Bool,
        isPersonLikeCounterparty: Bool
    ) -> (isEligible: Bool, reason: String?) {

        if transaction.type.uppercased() == "CREDIT" {
            return (true, "Credit transaction needs income/refund/self-transfer interpretation if not deterministic")
        }

        if transaction.amount >= 10_000 {
            return (true, "High-impact debit")
        }

        if isPersonLikeCounterparty {
            return (true, "Person-like counterparty")
        }

        if isPaymentProcessorOnly && transaction.amount >= 2_000 {
            return (true, "High-value payment processor-only transaction")
        }

        return (false, nil)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter.date(from: value)
    }
}
