import Foundation

struct AIReviewClassificationPayload: Encodable {
    let personaId: String
    let month: String
    let items: [AIClassificationRequest]
}

struct AIReviewClassificationResponse: Decodable {
    let suggestions: [AIClassificationSuggestion]
}

struct AIClassificationSuggestion: Decodable, Identifiable {
    var id: String { transactionId }

    let transactionId: String
    let role: String
    let categoryFamily: String
    let category: String
    let confidence: Int
    let needsReview: Bool
    let reviewQuestion: String?
    let evidence: [String]
}
