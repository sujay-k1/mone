import Foundation

enum AIReviewClassificationError: Error {
    case invalidURL
    case invalidResponse
    case serverError(String)
}

final class AIReviewClassificationClient {

    // Replace these with your actual values.
    // Use your existing Supabase config if you already have one.
    private let functionURL = "https://bvgswlacgejikbuuwnpy.supabase.co/functions/v1/classify-review-items"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2Z3N3bGFjZ2VqaWtidXV3bnB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMTI3OTgsImV4cCI6MjA5NDU4ODc5OH0.l-lY1HzQ70JML50xuwhPW7KkjSH5CHl5335gf1nWtzM"

    func classifyReviewItems(
        personaId: PersonaId,
        month: String,
        items: [AIClassificationRequest]
    ) async throws -> [AIClassificationSuggestion] {

        guard let url = URL(string: functionURL) else {
            throw AIReviewClassificationError.invalidURL
        }

        let payload = AIReviewClassificationPayload(
            personaId: personaId.rawValue,
            month: month,
            items: items
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIReviewClassificationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw AIReviewClassificationError.serverError(body)
        }

        let decoded = try JSONDecoder().decode(
            AIReviewClassificationResponse.self,
            from: data
        )

        return decoded.suggestions
    }
}
