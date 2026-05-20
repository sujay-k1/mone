import Foundation

final class ClassificationOverrideResolver {

    func resolve(
        base: ClassificationResult,
        aiSuggestion: AIClassificationSuggestion?
    ) -> ClassificationResult {
        guard let aiSuggestion else {
            return base
        }

        guard shouldAutoApply(aiSuggestion) else {
            return base
        }

        return ClassificationResult(
            transactionId: base.transactionId,
            canonicalEntityName: base.canonicalEntityName,
            entityType: "ai_suggested",
            role: aiSuggestion.role,
            categoryFamily: aiSuggestion.categoryFamily,
            category: aiSuggestion.category,
            confidence: aiSuggestion.confidence,
            evidence: base.evidence
                + ["AI suggestion auto-applied"]
                + aiSuggestion.evidence.map { "AI: \($0)" },
            needsReview: false,
            reviewReason: nil,
            reviewOptions: []
        )
    }

    private func shouldAutoApply(_ suggestion: AIClassificationSuggestion) -> Bool {
        if suggestion.needsReview {
            return false
        }

        if suggestion.confidence < 80 {
            return false
        }

        // AI can identify cash withdrawal, but cannot know how cash was spent.
        // Keep material cash in review/allocation flow.
        if suggestion.role == MoneRole.cashWithdrawal {
            return false
        }

        return true
    }
}
