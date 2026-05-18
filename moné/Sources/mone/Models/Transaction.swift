import Foundation

// MARK: - Transaction

struct Transaction: Identifiable, Codable {
    let id: UUID
    var merchant: String
    var amount: Double
    var date: Date
    var category: TransactionCategory
    var type: TransactionType
    var isUpcoming: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        merchant: String,
        amount: Double,
        date: Date = Date(),
        category: TransactionCategory,
        type: TransactionType = .debit,
        isUpcoming: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.category = category
        self.type = type
        self.isUpcoming = isUpcoming
        self.notes = notes
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var dateLabel: String {
        if isUpcoming {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days == 0 { return "Due today" }
            if days == 1 { return "Due tomorrow" }
            return "Due in \(days) days"
        }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    var amountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "₹\(formatted)"
    }
}

// MARK: - Transaction Category

enum TransactionCategory: String, CaseIterable, Codable {
    case all = "All"
    case food = "Food"
    case shopping = "Shopping"
    case bills = "Bills"
    case subscriptions = "Subscriptions"
    case creditCard = "Credit Card"
    case transport = "Transport"
    case housing = "Housing"
    case health = "Health"
    case entertainment = "Entertainment"
    case other = "Other"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .food: return "fork.knife"
        case .shopping: return "bag"
        case .bills: return "doc.text"
        case .subscriptions: return "repeat"
        case .creditCard: return "creditcard"
        case .transport: return "car"
        case .housing: return "house"
        case .health: return "cross.case"
        case .entertainment: return "tv"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Transaction Type

enum TransactionType: String, Codable {
    case debit, credit, upcoming
}
