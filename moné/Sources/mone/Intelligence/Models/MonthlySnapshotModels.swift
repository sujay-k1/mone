//
//  MonthlySnapshotModels.swift
//  mone
//
//  Created by Sujay Kumar on 20/05/26.
//

import Foundation

struct MonthlySnapshot: Identifiable {
    let id: String

    let personaId: PersonaId
    let month: String

    let income: Double
    let committed: Double
    let everyday: Double
    let fund: Double
    let liability: Double
    let outliers: Double
    let review: Double
    let remaining: Double

    let totalDebits: Double
    let classifiedDebits: Double
    let confidence: Int

    let transactionCount: Int
    let reviewCount: Int
}

struct ClassifiedTransaction {
    let transaction: RawTransaction
    let parsed: ParsedNarration
    let classification: ClassificationResult
}
