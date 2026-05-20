import Foundation

enum MoneyMapBucketKind: String, CaseIterable {
    case committed
    case everyday
    case fund
    case liability
    case tax
    case outliers
    case review
    case operatingRemaining
    case liquidCashImpact
    case neutral
}

struct MoneyMapBucket: Identifiable {
    var id: String { title }
    let title: String
    let amount: Double
    let kind: MoneyMapBucketKind
}

struct MoneyMapItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let amount: Double
    let status: String
    let symbolName: String
    let kind: MoneyMapBucketKind
}

struct MoneyMapCategoryGroup: Identifiable {
    var id: String { title }
    let title: String
    let amount: Double
    let transactionCount: Int
    let status: String
    let kind: MoneyMapBucketKind
}

struct MoneyMapScreenModel {
    let personaId: PersonaId
    let displayName: String
    let month: String

    let income: Double
    let confidence: Int
    let transactionCount: Int
    let reviewCount: Int

    let regularCommitted: Double
    let everyday: Double
    let fund: Double
    let liability: Double
    let taxDeduction: Double
    let outliers: Double
    let review: Double

    let operatingRemaining: Double
    let liquidCashImpact: Double
    let outstandingLiabilities: Double

    let committedItems: [MoneyMapItem]
    let everydayGroups: [MoneyMapCategoryGroup]
    let outlierItems: [MoneyMapItem]
    let fundItems: [MoneyMapItem]
    let liabilityItems: [MoneyMapItem]
    let reviewItems: [MoneyMapItem]

    var buckets: [MoneyMapBucket] {
        [
            MoneyMapBucket(title: "Committed", amount: regularCommitted, kind: .committed),
            MoneyMapBucket(title: "Everyday", amount: everyday, kind: .everyday),
            MoneyMapBucket(title: "Fund", amount: fund, kind: .fund),
            MoneyMapBucket(title: "Liability", amount: liability, kind: .liability),
            MoneyMapBucket(title: "Tax", amount: taxDeduction, kind: .tax),
            MoneyMapBucket(title: "Outliers", amount: outliers, kind: .outliers),
            MoneyMapBucket(title: "Review", amount: review, kind: .review),
            MoneyMapBucket(title: "Operating", amount: max(operatingRemaining, 0), kind: .operatingRemaining)
        ]
    }

    var positiveMapTotal: Double {
        max(
            regularCommitted + everyday + fund + liability + taxDeduction + outliers + review + max(operatingRemaining, 0),
            1
        )
    }

    var confidenceLabel: String {
        if confidence >= 85 { return "High confidence" }
        if confidence >= 70 { return "Good confidence" }
        if confidence >= 55 { return "Needs review" }
        return "Low confidence" }

    var statusLabel: String {
        if operatingRemaining < 0 { return "Operating shortfall" }
        if liquidCashImpact < 0 { return "Cash impact" }
        if reviewCount > 0 { return "Needs review" }
        return "Stable" }
}
