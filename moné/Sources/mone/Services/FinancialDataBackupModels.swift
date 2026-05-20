import Foundation

struct FinancialDataBackupPayload: Codable {
    let dataVersion: String
    let backedUpAt: String
    let persona: PersonaBackup
    let accounts: [AccountBackup]
    let transactions: [TransactionBackup]
    let classifications: [ClassificationBackup]
    let aiSuggestions: [AISuggestionBackup]
    let monthlySnapshots: [MonthlySnapshotBackup]
}

struct PersonaBackup: Codable {
    let id: String
    let displayName: String
    let lastSyncedAt: String
    let source: String
}

struct AccountBackup: Codable {
    let id: String
    let personaId: String
    let fipId: String
    let accountType: String
    let maskedAccountNumber: String?
    let currentBalance: Double?
    let currentValue: Double?
    let lastUpdatedAt: String
}

struct TransactionBackup: Codable {
    let id: String
    let personaId: String
    let accountId: String
    let accountType: String
    let type: String
    let mode: String
    let amount: Double
    let narration: String
    let valueDate: String?
    let timestamp: String?
    let month: String
    let currentBalance: Double?
    let normalizedCounterparty: String?
    let createdAt: String
}

struct ClassificationBackup: Codable {
    let id: String
    let transactionId: String
    let personaId: String
    let month: String
    let canonicalEntityName: String?
    let entityType: String
    let role: String
    let categoryFamily: String
    let category: String
    let confidence: Int
    let needsReview: Bool
    let reviewReason: String?
    let evidenceText: String
    let reviewOptionsText: String
    let source: String
    let createdAt: String
}

struct AISuggestionBackup: Codable {
    let id: String
    let transactionId: String
    let personaId: String
    let month: String
    let role: String
    let categoryFamily: String
    let category: String
    let confidence: Int
    let needsReview: Bool
    let reviewQuestion: String?
    let evidenceText: String
    let createdAt: String
}

struct MonthlySnapshotBackup: Codable {
    let id: String
    let personaId: String
    let month: String
    let income: Double
    let committed: Double
    let everyday: Double
    let fund: Double
    let liability: Double
    let outliers: Double
    let review: Double
    let remaining: Double
    let totalDebits: Double
    let classifiedDebits: Double
    let confidence: Int
    let transactionCount: Int
    let reviewCount: Int
    let createdAt: String
}
