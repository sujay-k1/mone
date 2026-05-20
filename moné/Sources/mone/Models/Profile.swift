import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    var phone: String?
    var email: String?
    var fullName: String?
    var onboardingStep: String?
    var onboardingCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case email
        case fullName = "full_name"
        case onboardingStep = "onboarding_step"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct ProfileUpsert: Encodable {
    let id: UUID
    let phone: String?
    let email: String?
    let fullName: String
    let onboardingStep: String
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case email
        case fullName = "full_name"
        case onboardingStep = "onboarding_step"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct ProfileReset: Encodable {
    let id: UUID
    let phone: String?
    let email: String?
    let fullName: String?
    let onboardingStep: String
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case email
        case fullName = "full_name"
        case onboardingStep = "onboarding_step"
        case onboardingCompleted = "onboarding_completed"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)

        if let phone {
            try container.encode(phone, forKey: .phone)
        } else {
            try container.encodeNil(forKey: .phone)
        }

        if let email {
            try container.encode(email, forKey: .email)
        } else {
            try container.encodeNil(forKey: .email)
        }

        if let fullName {
            try container.encode(fullName, forKey: .fullName)
        } else {
            try container.encodeNil(forKey: .fullName)
        }

        try container.encode(onboardingStep, forKey: .onboardingStep)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
    }
}
