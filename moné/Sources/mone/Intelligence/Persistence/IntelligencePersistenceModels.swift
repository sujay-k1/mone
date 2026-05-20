import Foundation
import SwiftData

@Model
final class StoredPersona {
    @Attribute(.unique) var id: String

    var displayName: String
    var lastSyncedAt: Date
    var source: String

    init(
        id: String,
        displayName: String,
        lastSyncedAt: Date,
        source: String
    ) {
        self.id = id
        self.displayName = displayName
        self.lastSyncedAt = lastSyncedAt
        self.source = source
    }
}

@Model
final class StoredAccount {
    @Attribute(.unique) var id: String

    var personaId: String
    var fipId: String
    var accountType: String
    var maskedAccountNumber: String?
    var currentBalance: Double?
    var currentValue: Double?
    var lastUpdatedAt: Date

    init(
        id: String,
        personaId: String,
        fipId: String,
        accountType: String,
        maskedAccountNumber: String?,
        currentBalance: Double?,
        currentValue: Double?,
        lastUpdatedAt: Date
    ) {
        self.id = id
        self.personaId = personaId
        self.fipId = fipId
        self.accountType = accountType
        self.maskedAccountNumber = maskedAccountNumber
        self.currentBalance = currentBalance
        self.currentValue = currentValue
        self.lastUpdatedAt = lastUpdatedAt
    }
}

@Model
final class StoredTransaction {
    @Attribute(.unique) var id: String

    var personaId: String
    var accountId: String
    var accountType: String

    var type: String
    var mode: String
    var amount: Double
    var narration: String

    var valueDate: String?
    var timestamp: String?
    var month: String

    var currentBalance: Double?

    var normalizedCounterparty: String?
    var createdAt: Date

    init(
        id: String,
        personaId: String,
        accountId: String,
        accountType: String,
        type: String,
        mode: String,
        amount: Double,
        narration: String,
        valueDate: String?,
        timestamp: String?,
        month: String,
        currentBalance: Double?,
        normalizedCounterparty: String?,
        createdAt: Date
    ) {
        self.id = id
        self.personaId = personaId
        self.accountId = accountId
        self.accountType = accountType
        self.type = type
        self.mode = mode
        self.amount = amount
        self.narration = narration
        self.valueDate = valueDate
        self.timestamp = timestamp
        self.month = month
        self.currentBalance = currentBalance
        self.normalizedCounterparty = normalizedCounterparty
        self.createdAt = createdAt
    }
}

@Model
final class StoredClassification {
    @Attribute(.unique) var id: String

    var transactionId: String
    var personaId: String
    var month: String

    var canonicalEntityName: String?
    var entityType: String

    var role: String
    var categoryFamily: String
    var category: String

    var confidence: Int
    var needsReview: Bool
    var reviewReason: String?

    var evidenceText: String
    var reviewOptionsText: String

    var source: String
    var createdAt: Date

    init(
        id: String,
        transactionId: String,
        personaId: String,
        month: String,
        canonicalEntityName: String?,
        entityType: String,
        role: String,
        categoryFamily: String,
        category: String,
        confidence: Int,
        needsReview: Bool,
        reviewReason: String?,
        evidenceText: String,
        reviewOptionsText: String,
        source: String,
        createdAt: Date
    ) {
        self.id = id
        self.transactionId = transactionId
        self.personaId = personaId
        self.month = month
        self.canonicalEntityName = canonicalEntityName
        self.entityType = entityType
        self.role = role
        self.categoryFamily = categoryFamily
        self.category = category
        self.confidence = confidence
        self.needsReview = needsReview
        self.reviewReason = reviewReason
        self.evidenceText = evidenceText
        self.reviewOptionsText = reviewOptionsText
        self.source = source
        self.createdAt = createdAt
    }
}

@Model
final class StoredAISuggestion {
    @Attribute(.unique) var id: String

    var transactionId: String
    var personaId: String
    var month: String

    var role: String
    var categoryFamily: String
    var category: String
    var confidence: Int
    var needsReview: Bool
    var reviewQuestion: String?

    var evidenceText: String
    var createdAt: Date

    init(
        id: String,
        transactionId: String,
        personaId: String,
        month: String,
        role: String,
        categoryFamily: String,
        category: String,
        confidence: Int,
        needsReview: Bool,
        reviewQuestion: String?,
        evidenceText: String,
        createdAt: Date
    ) {
        self.id = id
        self.transactionId = transactionId
        self.personaId = personaId
        self.month = month
        self.role = role
        self.categoryFamily = categoryFamily
        self.category = category
        self.confidence = confidence
        self.needsReview = needsReview
        self.reviewQuestion = reviewQuestion
        self.evidenceText = evidenceText
        self.createdAt = createdAt
    }
}

@Model
final class StoredMonthlySnapshot {
    @Attribute(.unique) var id: String

    var personaId: String
    var month: String

    var income: Double
    var committed: Double
    var everyday: Double
    var fund: Double
    var liability: Double
    var outliers: Double
    var review: Double
    var remaining: Double

    var totalDebits: Double
    var classifiedDebits: Double
    var confidence: Int

    var transactionCount: Int
    var reviewCount: Int

    var createdAt: Date

    init(
        id: String,
        personaId: String,
        month: String,
        income: Double,
        committed: Double,
        everyday: Double,
        fund: Double,
        liability: Double,
        outliers: Double,
        review: Double,
        remaining: Double,
        totalDebits: Double,
        classifiedDebits: Double,
        confidence: Int,
        transactionCount: Int,
        reviewCount: Int,
        createdAt: Date
    ) {
        self.id = id
        self.personaId = personaId
        self.month = month
        self.income = income
        self.committed = committed
        self.everyday = everyday
        self.fund = fund
        self.liability = liability
        self.outliers = outliers
        self.review = review
        self.remaining = remaining
        self.totalDebits = totalDebits
        self.classifiedDebits = classifiedDebits
        self.confidence = confidence
        self.transactionCount = transactionCount
        self.reviewCount = reviewCount
        self.createdAt = createdAt
    }
}

struct StoredTransactionRow: Identifiable {
    var id: String { transaction.id }

    let transaction: StoredTransaction
    let classification: StoredClassification?
}
