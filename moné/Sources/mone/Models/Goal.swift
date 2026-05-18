import Foundation

// MARK: - Goal

struct Goal: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: GoalType
    var targetAmount: Double
    var alreadySaved: Double
    var deadline: Date?
    var priority: GoalPriority
    var requiredMonthlyAllocation: Double?

    init(
        id: UUID = UUID(),
        name: String,
        type: GoalType,
        targetAmount: Double,
        alreadySaved: Double = 0,
        deadline: Date? = nil,
        priority: GoalPriority,
        requiredMonthlyAllocation: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.targetAmount = targetAmount
        self.alreadySaved = alreadySaved
        self.deadline = deadline
        self.priority = priority
        self.requiredMonthlyAllocation = requiredMonthlyAllocation
    }

    var progressFraction: Double {
        guard targetAmount > 0 else { return 0 }
        return min(alreadySaved / targetAmount, 1.0)
    }

    var remainingAmount: Double {
        max(targetAmount - alreadySaved, 0)
    }

    var progressPercent: Int {
        Int(progressFraction * 100)
    }
}

// MARK: - Goal Type

enum GoalType: String, CaseIterable, Codable {
    case emergencyFund = "Emergency Fund"
    case travel = "Travel"
    case bigPurchase = "Big Purchase"
    case homeVehicle = "Home or Vehicle"
    case education = "Education"
    case weddingEvent = "Wedding or Event"
    case medicalBuffer = "Medical Buffer"
    case investmentTarget = "Investment Target"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .emergencyFund: return "shield.checkered"
        case .travel: return "airplane"
        case .bigPurchase: return "bag"
        case .homeVehicle: return "house"
        case .education: return "book.closed"
        case .weddingEvent: return "sparkles"
        case .medicalBuffer: return "cross.case"
        case .investmentTarget: return "chart.line.uptrend.xyaxis"
        case .custom: return "flag"
        }
    }
}

// MARK: - Goal Priority

enum GoalPriority: String, CaseIterable, Codable {
    case mustProtect = "Must protect"
    case important = "Important"
    case flexible = "Flexible"

    var shortLabel: String {
        switch self {
        case .mustProtect: return "Must protect"
        case .important: return "Important"
        case .flexible: return "Flexible"
        }
    }

    var sortOrder: Int {
        switch self {
        case .mustProtect: return 0
        case .important: return 1
        case .flexible: return 2
        }
    }
}

// MARK: - Goal Status

enum GoalStatus: Equatable {
    case onTrack
    case atRisk(daysDelay: Int)
    case completed
    case noDeadline

    var label: String {
        switch self {
        case .onTrack: return "On track"
        case .atRisk(let days): return "\(days) day\(days == 1 ? "" : "s") behind"
        case .completed: return "Completed"
        case .noDeadline: return "No deadline"
        }
    }

    var isAtRisk: Bool {
        if case .atRisk = self { return true }
        return false
    }
}
