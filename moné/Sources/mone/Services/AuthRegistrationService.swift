import Foundation

struct RegistrationStatus: Decodable {
    let registered: Bool
    let lookupType: String?
    let phone: String?
    let email: String?
    let onboardingCompleted: Bool?
    let reason: String?
}

enum AuthRegistrationError: Error {
    case invalidResponse
    case serverError(String)
}

final class AuthRegistrationService {

    private let functionURL = SupabaseConfig.url
        .appendingPathComponent("functions")
        .appendingPathComponent("v1")
        .appendingPathComponent("check-phone-registration")

    func checkPhone(_ phone: String) async throws -> RegistrationStatus {
        try await check(identifierPayload: ["phone": phone])
    }

    func checkEmail(_ email: String) async throws -> RegistrationStatus {
        try await check(identifierPayload: ["email": email])
    }

    private func check(identifierPayload: [String: String]) async throws -> RegistrationStatus {
        let bodyData = try JSONEncoder().encode(identifierPayload)

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Because the function is deployed with --no-verify-jwt,
        // these headers are okay for a pre-login lookup.
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthRegistrationError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw AuthRegistrationError.serverError(text)
        }

        return try JSONDecoder().decode(RegistrationStatus.self, from: data)
    }
}
