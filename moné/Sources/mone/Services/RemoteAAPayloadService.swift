import Foundation

enum RemoteAAPayloadError: Error {
    case invalidURL
    case invalidResponse
    case missingPayload
    case unsupportedPersona(String)
    case serverError(String)
}

struct RemoteAAPayloadResult {
    let personaId: PersonaId
    let importResult: ImportResult
}

final class RemoteAAPayloadService {

    private let functionURL = "https://bvgswlacgejikbuuwnpy.supabase.co/functions/v1/fetch-aa-payload"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2Z3N3bGFjZ2VqaWtidXV3bnB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMTI3OTgsImV4cCI6MjA5NDU4ODc5OH0.l-lY1HzQ70JML50xuwhPW7KkjSH5CHl5335gf1nWtzM"

    private let importer = RawPayloadImporter()

    func fetchPayload(
        mobile: String,
        pan: String?,
        consentId: String?
    ) async throws -> RemoteAAPayloadResult {
        guard let url = URL(string: functionURL) else {
            throw RemoteAAPayloadError.invalidURL
        }

        let body: [String: Any?] = [
            "mobile": mobile,
            "pan": pan,
            "consentId": consentId
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAAPayloadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw RemoteAAPayloadError.serverError(text)
        }

        guard
            let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let personaRaw = envelope["personaId"] as? String,
            let payloadRoot = envelope["payload"] as? [[String: Any]]
        else {
            throw RemoteAAPayloadError.missingPayload
        }

        guard let personaId = PersonaId(rawValue: personaRaw) else {
            throw RemoteAAPayloadError.unsupportedPersona(personaRaw)
        }

        let importResult = try importer.importPayload(
            personaId: personaId,
            payloadRoot: payloadRoot,
            sourceName: "remote_aa_payload_\(personaRaw)"
        )

        return RemoteAAPayloadResult(
            personaId: personaId,
            importResult: importResult
        )
    }
}
