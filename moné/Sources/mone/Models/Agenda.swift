import Foundation

// MARK: - Agenda Types

enum AgendaType: String, CaseIterable, Identifiable, Codable {
    case controlSpending = "control_spending"
    case planGoals = "plan_goals"
    case understandPicture = "understand_picture"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlSpending: return "Control my spending"
        case .planGoals: return "Plan for goals"
        case .understandPicture: return "Understand my financial picture"
        }
    }

    var subtitle: String {
        switch self {
        case .controlSpending: return "Track leaks, avoid overspending, know safe-to-spend"
        case .planGoals: return "Save for important goals, know if on track"
        case .understandPicture: return "See cashflow, obligations, and net worth"
        }
    }

    var heroLabel: String {
        switch self {
        case .controlSpending: return "Safe-to-spend"
        case .planGoals: return "Goal health"
        case .understandPicture: return "Financial health"
        }
    }

    var icon: String {
        switch self {
        case .controlSpending: return "gauge.with.needle"
        case .planGoals: return "flag"
        case .understandPicture: return "chart.pie"
        }
    }

    var defaultNudgeIntensity: NudgeIntensity {
        switch self {
        case .controlSpending: return .balanced
        case .planGoals: return .gentle
        case .understandPicture: return .gentle
        }
    }
}

// MARK: - Nudge Intensity

enum NudgeIntensity: String, CaseIterable, Codable {
    case gentle = "Gentle"
    case balanced = "Balanced"
    case strict = "Strict"

    var description: String {
        switch self {
        case .gentle: return "Only alerts on real risk"
        case .balanced: return "Proactive but not intrusive"
        case .strict: return "Nudges on most discretionary spends"
        }
    }
}

// MARK: - Storage & Setup

enum StorageMode: String, Codable {
    case local = "local"
    case encryptedBackup = "encrypted_backup"
}

enum SetupMethod: String, Codable {
    case accountAggregator = "account_aggregator"
    case email = "email"
    case manual = "manual"

    var title: String {
        switch self {
        case .accountAggregator: return "Account Aggregator"
        case .email: return "Email"
        case .manual: return "Manual Setup"
        }
    }

    var subtitle: String {
        switch self {
        case .accountAggregator: return "Fastest — secure bank consent"
        case .email: return "Scan salary slips, bills, and statements"
        case .manual: return "Answer a few simple questions"
        }
    }

    var badge: String? {
        switch self {
        case .accountAggregator: return "Recommended"
        default: return nil
        }
    }

    var icon: String {
        switch self {
        case .accountAggregator: return "building.columns"
        case .email: return "envelope"
        case .manual: return "pencil.and.list.clipboard"
        }
    }
}
