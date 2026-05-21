import Foundation

enum PaymentGuidanceEngine {

    static func guidance(
        payload: UPIQRPayload,
        amount: Double,
        description: String,
        category: TransactionCategory,
        moneyMap: MoneyMap,
        spentThisWeek: Double
    ) -> PaymentGuidance {
        let impact = SafeToSpendCalculator.impactOfPayment(
            amount: amount,
            moneyMap: moneyMap,
            spentThisWeek: spentThisWeek
        )

        let vendorText = [
            payload.displayName,
            payload.payeeVPA,
            description
        ]
        .joined(separator: " ")
        .lowercased()

        if isMedical(vendorText, category: category) {
            return PaymentGuidance(
                title: "Hope everything is alright.",
                body: "This looks like a health expense, so I won’t treat it like avoidable spending. After this, you’ll have \(format(abs(impact.remainingAfterPayment))) \(impact.remainingAfterPayment >= 0 ? "left in your weekly safe-to-spend." : "over your weekly safe-to-spend.")",
                severity: .supportive,
                metric: impact.remainingAfterPayment >= 0 ? "Still within buffer" : "Cashflow pressure"
            )
        }

        if isVice(vendorText) {
            let monthlyRunRate = amount * 8
            return PaymentGuidance(
                title: "Small spends can become a pattern.",
                body: "If spends like this happen twice a week, this becomes about \(format(monthlyRunRate)) a month, or \(format(monthlyRunRate * 12)) a year.",
                severity: impact.riskLevel == .risk ? .risk : .watch,
                metric: "\(format(monthlyRunRate))/month pattern"
            )
        }

        if category == .shopping || isShopping(vendorText) {
            if impact.remainingAfterPayment < 0 {
                return PaymentGuidance(
                    title: "This will push you past your safe-to-spend.",
                    body: "After this payment, you’ll be \(format(abs(impact.remainingAfterPayment))) over your weekly buffer. This is the kind of spend that can quietly delay goals.",
                    severity: .risk,
                    metric: "\(format(abs(impact.remainingAfterPayment))) over"
                )
            }

            if impact.pctOfWeeklyBudget > 0.35 {
                return PaymentGuidance(
                    title: "Worth pausing before you pay.",
                    body: "This uses \(Int(impact.pctOfWeeklyBudget * 100))% of your weekly safe-to-spend. It may still be okay, but it is a meaningful chunk.",
                    severity: .watch,
                    metric: "\(Int(impact.pctOfWeeklyBudget * 100))% of weekly buffer"
                )
            }
        }

        if impact.remainingAfterPayment < 0 {
            return PaymentGuidance(
                title: "This payment creates pressure.",
                body: "You’ll be \(format(abs(impact.remainingAfterPayment))) over your weekly safe-to-spend after this.",
                severity: .risk,
                metric: "\(format(abs(impact.remainingAfterPayment))) over"
            )
        }

        if impact.pctOfWeeklyBudget > 0.4 {
            return PaymentGuidance(
                title: "This is a large payment for the week.",
                body: "You’ll still have \(format(impact.remainingAfterPayment)) left, but this uses \(Int(impact.pctOfWeeklyBudget * 100))% of your weekly buffer.",
                severity: .watch,
                metric: "\(Int(impact.pctOfWeeklyBudget * 100))% of weekly buffer"
            )
        }

        return PaymentGuidance(
            title: "This looks okay.",
            body: "After this payment, you’ll have \(format(impact.remainingAfterPayment)) left in your weekly safe-to-spend.",
            severity: .calm,
            metric: "\(format(impact.remainingAfterPayment)) left"
        )
    }

    static func inferCategory(from payload: UPIQRPayload, description: String) -> TransactionCategory {
        let text = "\(payload.displayName) \(payload.payeeVPA) \(description)".lowercased()

        if isMedical(text, category: nil) { return .health }

        if text.contains("coffee") ||
            text.contains("cafe") ||
            text.contains("restaurant") ||
            text.contains("food") ||
            text.contains("swiggy") ||
            text.contains("zomato") {
            return .food
        }

        if isShopping(text) { return .shopping }

        if text.contains("uber") ||
            text.contains("ola") ||
            text.contains("metro") ||
            text.contains("fuel") ||
            text.contains("petrol") {
            return .transport
        }

        if text.contains("electricity") ||
            text.contains("broadband") ||
            text.contains("mobile") ||
            text.contains("bill") {
            return .bills
        }

        return .other
    }

    private static func isMedical(_ text: String, category: TransactionCategory?) -> Bool {
        if category == .health { return true }

        return text.contains("medical") ||
            text.contains("clinic") ||
            text.contains("hospital") ||
            text.contains("pharma") ||
            text.contains("chemist") ||
            text.contains("doctor") ||
            text.contains("diagnostic")
    }

    private static func isVice(_ text: String) -> Bool {
        text.contains("wine") ||
            text.contains("beer") ||
            text.contains("liquor") ||
            text.contains("tobacco") ||
            text.contains("cigarette") ||
            text.contains("smoke")
    }

    private static func isShopping(_ text: String) -> Bool {
        text.contains("zara") ||
            text.contains("myntra") ||
            text.contains("ajio") ||
            text.contains("amazon") ||
            text.contains("flipkart") ||
            text.contains("mall") ||
            text.contains("fashion") ||
            text.contains("store")
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}
