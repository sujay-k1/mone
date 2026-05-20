import Foundation

struct KnownEntity {
    let canonicalName: String
    let aliases: [String]
    let entityType: String
    let role: String
    let categoryFamily: String
    let category: String
    let confidenceBase: Int
    let isPaymentProcessor: Bool
}

struct ClassificationResult {
    let transactionId: String

    let canonicalEntityName: String?
    let entityType: String

    let role: String
    let categoryFamily: String
    let category: String

    let confidence: Int
    let evidence: [String]

    let needsReview: Bool
    let reviewReason: String?
    let reviewOptions: [String]
}
