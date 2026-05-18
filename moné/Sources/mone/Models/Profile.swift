import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    var fullName: String?
    var onboardingStep: String?
    var onboardingCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case onboardingStep = "onboarding_step"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct ProfileUpsert: Encodable {
    let id: UUID
    let fullName: String
    let onboardingStep: String
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case onboardingStep = "onboarding_step"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct ProfileReset: Encodable {
    let id: UUID
    let fullName: String?
    let onboardingStep: String
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case onboardingStep = "onboarding_step"
        case onboardingCompleted = "onboarding_completed"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if let fullName {
            try container.encode(fullName, forKey: .fullName)
        } else {
            try container.encodeNil(forKey: .fullName)
        }
        try container.encode(onboardingStep, forKey: .onboardingStep)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
    }
}
