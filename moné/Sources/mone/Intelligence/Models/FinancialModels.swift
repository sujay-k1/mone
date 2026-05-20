import Foundation

enum PersonaId: String {
    case aarav
    case priya
}

struct FinancialAccount: Identifiable {
    let id: String
    let personaId: PersonaId
    let fipId: String
    let accountType: String
    let maskedAccountNumber: String?
    let currentBalance: Double?
    let currentValue: Double?
}

struct RawTransaction: Identifiable {
    let id: String
    let personaId: PersonaId
    let accountId: String
    let accountType: String
    let type: String
    let mode: String
    let amount: Double
    let narration: String
    let valueDate: String?
    let timestamp: String?
    let currentBalance: Double?
}

struct ImportResult {
    let personaId: PersonaId
    let accounts: [FinancialAccount]
    let transactions: [RawTransaction]
}//
//  FinancialModels.swift
//  mone
//
//  Created by Sujay Kumar on 20/05/26.
//

