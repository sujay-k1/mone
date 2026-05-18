import Foundation

// MARK: - Mock Data Service

struct MockDataService {

    // MARK: - Money Map

    static func defaultMoneyMap() -> MoneyMap {
        var map = MoneyMap()
        map.income        = defaultIncome()
        map.obligations   = defaultObligations()
        map.subscriptions = defaultSubscriptions()
        map.goals         = defaultGoals()
        map.upcomingItems = defaultUpcoming()
        return map
    }

    // MARK: - Income

    static func defaultIncome() -> [IncomeSource] {
        [
            IncomeSource(name: "Salary — Atlassian", amount: 182000,
                         frequency: .monthly, type: .stable, typicalDay: 28),
            IncomeSource(name: "Freelance consulting", amount: 24000,
                         frequency: .irregular, type: .variable)
        ]
    }

    // MARK: - Obligations

    static func defaultObligations() -> [Obligation] {
        [
            Obligation(name: "Rent",           amount: 42000, category: .housing,       dueDay: 5,  isConfirmed: true),
            Obligation(name: "Home Loan EMI",  amount: 18400, category: .debt,          dueDay: 7,  isConfirmed: true),
            Obligation(name: "SIP",            amount: 15000, category: .investments,   dueDay: 10, isConfirmed: true),
            Obligation(name: "Health Insurance", amount: 3200, category: .insurance,               isConfirmed: true),
            Obligation(name: "HDFC Credit Card", amount: 28400, category: .debt,        dueDay: 23, isConfirmed: true),
            Obligation(name: "Broadband",      amount: 1499,  category: .utilities,     dueDay: 26, isConfirmed: true)
        ]
    }

    // MARK: - Subscriptions

    static func defaultSubscriptions() -> [SubscriptionItem] {
        [
            SubscriptionItem(name: "Netflix",  monthlyAmount: 649, billingDay: 15, isConfirmed: true),
            SubscriptionItem(name: "iCloud+",  monthlyAmount: 199, billingDay: 20, isConfirmed: true),
            SubscriptionItem(name: "Spotify",  monthlyAmount: 119, billingDay: 18, isConfirmed: true)
        ]
    }

    // MARK: - Goals

    static func defaultGoals() -> [Goal] {
        let cal = Calendar.current
        let vacation = cal.date(byAdding: .month, value: 6,  to: Date())!
        let laptop   = cal.date(byAdding: .month, value: 8,  to: Date())!

        return [
            Goal(name: "Emergency Fund", type: .emergencyFund,
                 targetAmount: 400000, alreadySaved: 240000,
                 priority: .mustProtect, requiredMonthlyAllocation: 10000),
            Goal(name: "Vacation — Bali", type: .travel,
                 targetAmount: 120000, alreadySaved: 30000,
                 deadline: vacation, priority: .important, requiredMonthlyAllocation: 15000),
            Goal(name: "Laptop Upgrade", type: .bigPurchase,
                 targetAmount: 100000, alreadySaved: 35000,
                 deadline: laptop, priority: .flexible, requiredMonthlyAllocation: 8000)
        ]
    }

    // MARK: - Upcoming

    static func defaultUpcoming() -> [UpcomingItem] {
        let cal = Calendar.current
        let now = Date()
        return [
            UpcomingItem(name: "HDFC Credit Card", amount: 28400,
                         dueDate: cal.date(byAdding: .day, value: 5,  to: now)!, type: .creditCard),
            UpcomingItem(name: "Broadband",         amount: 1499,
                         dueDate: cal.date(byAdding: .day, value: 8,  to: now)!, type: .bill),
            UpcomingItem(name: "Rent",              amount: 42000,
                         dueDate: cal.date(byAdding: .day, value: 12, to: now)!, type: .emi)
        ]
    }

    // MARK: - Transactions

    static func defaultTransactions() -> [Transaction] {
        let cal = Calendar.current
        let now = Date()
        func ago(_ days: Int) -> Date { cal.date(byAdding: .day, value: -days, to: now)! }
        func due(_ days: Int) -> Date { cal.date(byAdding: .day, value:  days, to: now)! }

        return [
            Transaction(merchant: "Swiggy",           amount: 640,   date: ago(0), category: .food),
            Transaction(merchant: "Third Wave Coffee", amount: 420,   date: ago(0), category: .food),
            Transaction(merchant: "Zara",              amount: 3200,  date: ago(1), category: .shopping),
            Transaction(merchant: "Uber",              amount: 280,   date: ago(1), category: .transport),
            Transaction(merchant: "Blinkit",           amount: 1840,  date: ago(2), category: .food),
            Transaction(merchant: "Amazon",            amount: 2499,  date: ago(3), category: .shopping),
            Transaction(merchant: "Netflix",           amount: 649,   date: ago(5), category: .subscriptions),
            Transaction(merchant: "HDFC Credit Card",  amount: 28400, date: due(5),
                        category: .creditCard, type: .upcoming, isUpcoming: true),
            Transaction(merchant: "Rent",              amount: 42000, date: due(12),
                        category: .housing, type: .upcoming, isUpcoming: true)
        ]
    }

    // MARK: - Insight Cards

    static func defaultInsights() -> [InsightCardData] {
        [
            InsightCardData(
                title: "Food delivery is 34% above usual",
                detail: "₹4,280 this week vs ₹3,200 average",
                actionLabel: "Review",
                type: .watch
            ),
            InsightCardData(
                title: "Vacation goal may slip by 12 days",
                detail: "At current pace, you'll arrive in January",
                actionLabel: "Adjust",
                type: .watch
            ),
            InsightCardData(
                title: "₹967/month in subscriptions",
                detail: "Netflix, Spotify, iCloud+",
                actionLabel: "Review",
                type: .info
            ),
            InsightCardData(
                title: "Credit card due in 5 days",
                detail: "₹28,400 — full payment avoids interest",
                actionLabel: "Note it",
                type: .risk
            )
        ]
    }
}
