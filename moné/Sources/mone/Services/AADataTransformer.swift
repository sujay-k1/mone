import Foundation

struct AATransformResult {
    let moneyMap: MoneyMap
    let transactions: [Transaction]
    let insights: [InsightCardData]
}

enum AADataTransformer {

    static func transform(response: SyntheticAAResponse) -> AATransformResult {
        let bundle = response.sourceBundle
        let depositRows = bundle.transactions.rows.filter { $0["fi_type"] == "deposit" }
        let parsedTransactions = depositRows
            .compactMap(parseSourceTransaction)
            .sorted { $0.date > $1.date }

        let income = detectIncome(from: depositRows)
        var obligations = detectObligations(from: depositRows)
        obligations.append(contentsOf: detectDeviceFinanceObligations(from: bundle.deviceFinanceSource))
        obligations = dedupeObligations(obligations)

        let subscriptions = detectSubscriptions(from: depositRows)
        let goals = inferGoals(income: income, asOfDate: response.asOfDate)
        let upcoming = detectUpcoming(
            obligations: obligations,
            subscriptions: subscriptions,
            creditCardRows: bundle.creditCardSummary.rows,
            asOfDate: response.asOfDate
        )

        let moneyMap = MoneyMap(
            income: income,
            obligations: obligations,
            subscriptions: subscriptions,
            goals: goals,
            upcomingItems: upcoming,
            lastUpdated: response.asOfDate
        )

        let balance = depositClosingBalance(from: bundle.accounts)
        let insights = generateInsights(
            transactions: parsedTransactions,
            moneyMap: moneyMap,
            balance: balance,
            creditCardRows: bundle.creditCardSummary.rows,
            deviceFinanceSource: bundle.deviceFinanceSource
        )

        return AATransformResult(
            moneyMap: moneyMap,
            transactions: parsedTransactions,
            insights: insights
        )
    }

    static func transform(payload: AAPayload) -> AATransformResult {
        let transactions = payload.fips.flatMap(\.data).flatMap { $0.decryptedFI.account.transactions.transaction }
        let parsedTransactions = transactions
            .filter { $0.type == "DEBIT" || $0.type == "CREDIT" }
            .compactMap(parseAATransaction)
            .sorted { $0.date > $1.date }

        let income = detectIncome(from: transactions)
        let obligations = detectObligations(from: transactions)
        let subscriptions = detectSubscriptions(from: transactions)
        let goals = inferGoals(income: income, asOfDate: Date())
        let upcoming = detectUpcoming(
            obligations: obligations,
            subscriptions: subscriptions,
            creditCardRows: [],
            asOfDate: Date()
        )
        let balance = payload.fips
            .flatMap(\.data)
            .first(where: { $0.decryptedFI.type == "deposit" })?
            .decryptedFI.account.summary.sourceBalance ?? 0

        let moneyMap = MoneyMap(
            income: income,
            obligations: obligations,
            subscriptions: subscriptions,
            goals: goals,
            upcomingItems: upcoming,
            lastUpdated: Date()
        )

        return AATransformResult(
            moneyMap: moneyMap,
            transactions: parsedTransactions,
            insights: generateInsights(
                transactions: parsedTransactions,
                moneyMap: moneyMap,
                balance: balance,
                creditCardRows: [],
                deviceFinanceSource: .object([:])
            )
        )
    }

    // MARK: - Source Transaction Parsing

    private static func parseSourceTransaction(_ row: [String: String]) -> Transaction? {
        guard let amount = row.double("amount"), amount > 0 else { return nil }
        let date = parseDate(row["timestamp"] ?? "") ?? parseDate(row["date"] ?? "") ?? Date()
        let narration = row["narration"] ?? ""
        let mode = row["mode"] ?? ""
        let merchant = extractMerchant(from: narration)
        let category = inferCategory(from: narration, mode: mode, amount: amount)
        let type: TransactionType = row["direction"] == "CREDIT" ? .credit : .debit

        return Transaction(
            merchant: merchant,
            amount: amount,
            date: date,
            category: category,
            type: type,
            notes: row["transaction_id"]
        )
    }

    private static func parseAATransaction(_ transaction: AATransaction) -> Transaction? {
        guard let amount = Double(transaction.amount), amount > 0 else { return nil }
        let date = parseDate(transaction.transactionTimestamp) ?? parseDate(transaction.valueDate) ?? Date()
        return Transaction(
            merchant: extractMerchant(from: transaction.narration),
            amount: amount,
            date: date,
            category: inferCategory(from: transaction.narration, mode: transaction.mode, amount: amount),
            type: transaction.type == "CREDIT" ? .credit : .debit,
            notes: transaction.txnId
        )
    }

    private static func extractMerchant(from narration: String) -> String {
        let parts = narration.components(separatedBy: "/")
        if parts.count >= 3 {
            return parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return narration.prefix(34).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inferCategory(from narration: String, mode: String, amount: Double) -> TransactionCategory {
        let lower = narration.lowercased()

        if lower.contains("salary") { return .other }
        if lower.contains("rent") || lower.contains("landlord") { return .housing }
        if lower.contains("credit card") || lower.contains("card bill") { return .creditCard }
        if lower.contains("emi") || lower.contains("bajaj") || lower.contains("loan") || lower.contains("late fee") || lower.contains("interest") { return .bills }
        if lower.contains("sip") || lower.contains("mutual fund") || lower.contains("rd ") || lower.contains("fd ") || lower.contains("premium") { return .bills }
        if lower.contains("electricity") || lower.contains("bescom") || lower.contains("broadband") || lower.contains("airtel") || lower.contains("jio") { return .bills }
        if lower.contains("netflix") || lower.contains("spotify") || lower.contains("prime") || lower.contains("icloud") || lower.contains("hotstar") { return .subscriptions }
        if lower.contains("swiggy") || lower.contains("zomato") || lower.contains("coffee") || lower.contains("restaurant") || lower.contains("toit") || lower.contains("truffles") || lower.contains("grocery") || lower.contains("bigbasket") { return .food }
        if lower.contains("uber") || lower.contains("ola") || lower.contains("rapido") || lower.contains("metro") { return .transport }
        if lower.contains("apple") || lower.contains("sony") || lower.contains("myntra") || lower.contains("zara") || lower.contains("nike") || lower.contains("amazon") || lower.contains("flipkart") { return .shopping }
        if lower.contains("flight") || lower.contains("hotel") || lower.contains("travel") || lower.contains("makemytrip") { return .entertainment }
        if lower.contains("pharma") || lower.contains("clinic") || lower.contains("hospital") { return .health }

        return .other
    }

    // MARK: - Income

    private static func detectIncome(from rows: [[String: String]]) -> [IncomeSource] {
        let salaryRows = rows.filter {
            $0["direction"] == "CREDIT" &&
            ($0["narration"] ?? "").localizedCaseInsensitiveContains("salary")
        }
        let salaryAmounts = salaryRows.compactMap { $0.double("amount") }
        let salary = salaryAmounts.isEmpty ? 165_000 : salaryAmounts.reduce(0, +) / Double(salaryAmounts.count)
        let salaryDay = salaryRows.compactMap { parseDate($0["date"] ?? "") }
            .map { Calendar.current.component(.day, from: $0) }
            .first ?? 28

        var income = [
            IncomeSource(
                name: "ACME Tech Salary",
                amount: salary,
                frequency: .monthly,
                type: .stable,
                typicalDay: salaryDay
            )
        ]

        let variableCredits = rows.filter { row in
            guard row["direction"] == "CREDIT", let amount = row.double("amount"), amount >= 5_000 else {
                return false
            }
            let lower = (row["narration"] ?? "").lowercased()
            return !lower.contains("salary") &&
            !lower.contains("reimbursement") &&
            !lower.contains("refund") &&
            !lower.contains("redemption") &&
            !lower.contains("closure") &&
            !lower.contains("fd") &&
            !lower.contains("rd")
        }

        if !variableCredits.isEmpty {
            let average = variableCredits.compactMap { $0.double("amount") }.reduce(0, +) / Double(variableCredits.count)
            income.append(IncomeSource(
                name: "Variable credits",
                amount: average,
                frequency: .irregular,
                type: .variable
            ))
        }

        return income
    }

    private static func detectIncome(from transactions: [AATransaction]) -> [IncomeSource] {
        let salaryRows = transactions.filter { $0.type == "CREDIT" && $0.narration.localizedCaseInsensitiveContains("salary") }
        let salaryAmounts = salaryRows.compactMap { Double($0.amount) }
        let salary = salaryAmounts.isEmpty ? 165_000 : salaryAmounts.reduce(0, +) / Double(salaryAmounts.count)
        return [
            IncomeSource(
                name: "ACME Tech Salary",
                amount: salary,
                frequency: .monthly,
                type: .stable,
                typicalDay: 28
            )
        ]
    }

    // MARK: - Commitments

    private static func detectObligations(from rows: [[String: String]]) -> [Obligation] {
        var grouped: [String: [[String: String]]] = [:]

        for row in rows where row["direction"] == "DEBIT" {
            let key = obligationKey(row["narration"] ?? "")
            guard key != nil else { continue }
            grouped[key!, default: []].append(row)
        }

        var obligations: [Obligation] = []
        for (key, rows) in grouped {
            guard rows.count >= 2 || key.contains("emi") || key.contains("card") else { continue }
            let amounts = rows.compactMap { $0.double("amount") }
            guard !amounts.isEmpty else { continue }
            let average = amounts.reduce(0, +) / Double(amounts.count)
            guard average >= 300 else { continue }

            let narration = rows.first?["narration"] ?? key
            obligations.append(Obligation(
                name: obligationName(for: key, narration: narration),
                amount: average,
                category: obligationCategory(for: key, narration: narration),
                dueDay: typicalDay(rows),
                isMonthly: true,
                isConfirmed: false
            ))
        }

        return obligations
    }

    private static func detectObligations(from transactions: [AATransaction]) -> [Obligation] {
        let rows = transactions.map {
            [
                "direction": $0.type,
                "amount": $0.amount,
                "narration": $0.narration,
                "date": $0.valueDate
            ]
        }
        return detectObligations(from: rows)
    }

    private static func detectDeviceFinanceObligations(from source: JSONValue) -> [Obligation] {
        guard case .object(let object) = source else { return [] }
        let monthlyEMI = doubleValue(object["monthly_emi"]) ?? doubleValue(object["monthlyEMI"]) ?? 0
        guard monthlyEMI > 0 else { return [] }
        let lender = object["lender"] as? String ?? "Device finance"

        return [
            Obligation(
                name: "\(lender) EMI",
                amount: monthlyEMI,
                category: .debt,
                dueDay: day(from: object["first_due_date"] as? String) ?? 5,
                isMonthly: true,
                isConfirmed: false
            )
        ]
    }

    private static func detectSubscriptions(from rows: [[String: String]]) -> [SubscriptionItem] {
        let keywords = ["netflix", "spotify", "prime", "icloud", "hotstar", "youtube"]
        var grouped: [String: [[String: String]]] = [:]

        for row in rows where row["direction"] == "DEBIT" {
            let lower = (row["narration"] ?? "").lowercased()
            guard let key = keywords.first(where: { lower.contains($0) }) else { continue }
            grouped[key, default: []].append(row)
        }

        return grouped.map { key, rows in
            let amounts = rows.compactMap { $0.double("amount") }
            let average = amounts.isEmpty ? 0 : amounts.reduce(0, +) / Double(amounts.count)
            return SubscriptionItem(
                name: key.capitalized,
                monthlyAmount: average,
                billingDay: typicalDay(rows),
                isConfirmed: false
            )
        }
        .sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    private static func detectSubscriptions(from transactions: [AATransaction]) -> [SubscriptionItem] {
        let rows = transactions.map {
            [
                "direction": $0.type,
                "amount": $0.amount,
                "narration": $0.narration,
                "date": $0.valueDate
            ]
        }
        return detectSubscriptions(from: rows)
    }

    private static func obligationKey(_ narration: String) -> String? {
        let lower = narration.lowercased()
        if lower.contains("rent") || lower.contains("landlord") { return "rent" }
        if lower.contains("credit card") || lower.contains("card bill") { return "credit_card_bill" }
        if lower.contains("bajaj") || lower.contains("device emi") { return "device_emi" }
        if lower.contains("emi") || lower.contains("loan") { return "emi" }
        if lower.contains("sip") && lower.contains("hdfc") { return "sip_hdfc" }
        if lower.contains("sip") && lower.contains("axis") { return "sip_axis" }
        if lower.contains("sip") { return "sip" }
        if lower.contains("insurance") || lower.contains("premium") { return "insurance" }
        if lower.contains("broadband") || lower.contains("airtel") || lower.contains("jio") { return "broadband" }
        if lower.contains("electricity") || lower.contains("bescom") { return "electricity" }
        return nil
    }

    private static func obligationName(for key: String, narration: String) -> String {
        switch key {
        case "rent": return "Rent"
        case "credit_card_bill": return "Credit card bill"
        case "device_emi": return "Device EMI"
        case "emi": return "EMI"
        case "sip_hdfc": return "HDFC Bluechip SIP"
        case "sip_axis": return "Axis Midcap SIP"
        case "sip": return "SIP"
        case "insurance": return "Insurance premium"
        case "broadband": return "Broadband / mobile"
        case "electricity": return "Electricity"
        default: return extractMerchant(from: narration)
        }
    }

    private static func obligationCategory(for key: String, narration: String) -> ObligationCategory {
        if key == "rent" { return .housing }
        if key.contains("emi") || key.contains("card") { return .debt }
        if key.contains("sip") { return .investments }
        if key == "insurance" { return .insurance }
        if key == "broadband" || key == "electricity" { return .utilities }
        return obligationCategory(from: narration)
    }

    private static func obligationCategory(from narration: String) -> ObligationCategory {
        let lower = narration.lowercased()
        if lower.contains("rent") { return .housing }
        if lower.contains("emi") || lower.contains("loan") || lower.contains("card") { return .debt }
        if lower.contains("sip") || lower.contains("mutual") { return .investments }
        if lower.contains("insurance") || lower.contains("premium") { return .insurance }
        if lower.contains("electricity") || lower.contains("broadband") { return .utilities }
        return .lifestyle
    }

    private static func dedupeObligations(_ obligations: [Obligation]) -> [Obligation] {
        var seen: Set<String> = []
        var result: [Obligation] = []
        for obligation in obligations.sorted(by: { $0.amount > $1.amount }) {
            let key = obligation.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(obligation)
        }
        return result
    }

    // MARK: - Goals / Upcoming

    private static func inferGoals(income: [IncomeSource], asOfDate: Date) -> [Goal] {
        let monthlyIncome = income.filter { $0.type == .stable }.reduce(0.0) { $0 + $1.amount }
        return [
            Goal(
                name: "Emergency Fund",
                type: .emergencyFund,
                targetAmount: max(monthlyIncome * 4, 500_000),
                alreadySaved: 120_000,
                deadline: nil,
                priority: .mustProtect,
                requiredMonthlyAllocation: 20_000
            ),
            Goal(
                name: "Vacation",
                type: .travel,
                targetAmount: 180_000,
                alreadySaved: 42_000,
                deadline: Calendar.current.date(byAdding: .month, value: 7, to: asOfDate),
                priority: .important,
                requiredMonthlyAllocation: 18_000
            ),
            Goal(
                name: "Laptop buffer",
                type: .bigPurchase,
                targetAmount: 160_000,
                alreadySaved: 25_000,
                deadline: Calendar.current.date(byAdding: .month, value: 10, to: asOfDate),
                priority: .flexible,
                requiredMonthlyAllocation: 12_000
            )
        ]
    }

    private static func detectUpcoming(
        obligations: [Obligation],
        subscriptions: [SubscriptionItem],
        creditCardRows: [[String: String]],
        asOfDate: Date
    ) -> [UpcomingItem] {
        var upcoming = obligations.map {
            UpcomingItem(
                name: $0.name,
                amount: $0.amount,
                dueDate: nextDate(day: $0.dueDay ?? 5, after: asOfDate),
                type: $0.category == .debt ? .emi : .bill
            )
        }

        upcoming.append(contentsOf: subscriptions.map {
            UpcomingItem(
                name: $0.name,
                amount: $0.monthlyAmount,
                dueDate: nextDate(day: $0.billingDay ?? 15, after: asOfDate),
                type: .subscription
            )
        })

        if let riskyStatement = creditCardRows
            .filter({ ($0["payment_status"] ?? "").lowercased() != "full" })
            .sorted(by: { ($0["due_date"] ?? "") > ($1["due_date"] ?? "") })
            .first,
           let due = parseDate(riskyStatement["due_date"] ?? "") {
            upcoming.append(UpcomingItem(
                name: "Credit card due",
                amount: riskyStatement.double("total_amount_due") ?? 0,
                dueDate: due,
                type: .creditCard
            ))
        }

        return upcoming.sorted { $0.dueDate < $1.dueDate }
    }

    private static func nextDate(day: Int, after date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        let base = calendar.dateComponents([.year, .month], from: date)
        let thisMonth = calendar.date(from: DateComponents(year: base.year, month: base.month, day: min(day, 28))) ?? date
        if thisMonth > date { return thisMonth }
        return calendar.date(byAdding: .month, value: 1, to: thisMonth) ?? date
    }

    // MARK: - Insights

    private static func generateInsights(
        transactions: [Transaction],
        moneyMap: MoneyMap,
        balance: Double,
        creditCardRows: [[String: String]],
        deviceFinanceSource: JSONValue
    ) -> [InsightCardData] {
        var insights: [InsightCardData] = []
        let debitTransactions = transactions.filter { $0.type == .debit }
        let foodSpend = debitTransactions.filter { $0.category == .food }.reduce(0.0) { $0 + $1.amount }
        let transportSpend = debitTransactions.filter { $0.category == .transport }.reduce(0.0) { $0 + $1.amount }
        let shoppingSpend = debitTransactions.filter { $0.category == .shopping }.reduce(0.0) { $0 + $1.amount }
        let totalDebit = debitTransactions.reduce(0.0) { $0 + $1.amount }

        if moneyMap.safeToSpendMonthly <= 0 {
            insights.append(InsightCardData(
                title: "Safe-to-spend is under pressure",
                detail: "Income is strong, but fixed commitments, debt, goals, and recurring leaks leave little room for new discretionary spend.",
                actionLabel: "Review safe-to-spend",
                type: .risk
            ))
        }

        if let riskyCard = creditCardRows.first(where: { row in
            (row["payment_status"] ?? "").lowercased() == "partial" ||
            (row["payment_status"] ?? "").lowercased() == "late" ||
            (row.double("utilization_ratio") ?? 0) > 0.6
        }) {
            let due = riskyCard.double("total_amount_due") ?? 0
            insights.append(InsightCardData(
                title: "Credit card pressure detected",
                detail: "A card statement shows \(formatAmount(due)) due with \(riskyCard["payment_status"] ?? "risk") payment behavior. Treat this as debt pressure before new spends.",
                actionLabel: "Check card cycle",
                type: .risk
            ))
        }

        if totalDebit > 0, foodSpend / totalDebit > 0.18 {
            insights.append(InsightCardData(
                title: "Food and coffee leaks are visible",
                detail: "Small delivery, coffee, and dining payments add up to \(formatAmount(foodSpend)) across the loaded period.",
                actionLabel: "View food spends",
                type: .watch
            ))
        }

        if shoppingSpend > 150_000 {
            insights.append(InsightCardData(
                title: "Rash purchases moved the plan",
                detail: "\(formatAmount(shoppingSpend)) in shopping and gadgets is enough to delay goals unless you rebalance.",
                actionLabel: "Review goal impact",
                type: .risk
            ))
        }

        if transportSpend > 60_000 {
            insights.append(InsightCardData(
                title: "Cab spend is a recurring leak",
                detail: "Ride-hailing and commute spends total \(formatAmount(transportSpend)). Moné will keep this as a weekly signal, not an interrupt.",
                actionLabel: "See commute pattern",
                type: .watch
            ))
        }

        if case .object(let object) = deviceFinanceSource,
           let monthlyEMI = doubleValue(object["monthly_emi"]),
           monthlyEMI > 0 {
            insights.append(InsightCardData(
                title: "Device EMI added future pressure",
                detail: "\(formatAmount(monthlyEMI)) is now reserved each month before safe-to-spend.",
                actionLabel: "Review EMIs",
                type: .watch
            ))
        }

        if balance > 0, moneyMap.safeToSpendMonthly <= 0 {
            insights.append(InsightCardData(
                title: "Balance is not safe-to-spend",
                detail: "Your bank balance is positive, but upcoming commitments can still make safe-to-spend negative.",
                actionLabel: "View commitments",
                type: .info
            ))
        }

        return insights
    }

    // MARK: - Helpers

    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        return formatter
    }()

    private static func parseDate(_ value: String) -> Date? {
        isoParser.date(from: value) ?? dateParser.date(from: value)
    }

    private static func typicalDay(_ rows: [[String: String]]) -> Int? {
        rows.compactMap { parseDate($0["date"] ?? "") }
            .map { Calendar.current.component(.day, from: $0) }
            .sorted()
            .first
    }

    private static func day(from value: String?) -> Int? {
        guard let value, let date = parseDate(value) else { return nil }
        return Calendar.current.component(.day, from: date)
    }

    private static func depositClosingBalance(from accounts: CSVTable) -> Double {
        accounts.rows.first(where: { $0["fi_type"] == "deposit" })?.double("closing_balance") ?? 0
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return "₹\(formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }
}

private extension Dictionary where Key == String, Value == String {
    func double(_ key: String) -> Double? {
        guard let value = self[key], !value.isEmpty else { return nil }
        return Double(value)
    }
}
