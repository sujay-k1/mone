import Foundation

enum MoneRole {
    static let income = "income"
    static let committedOutflow = "committed_outflow"
    static let everydaySpend = "everyday_spend"
    static let fundBuilding = "fund_building"
    static let liabilityPayment = "liability_payment"
    static let selfTransfer = "self_transfer"
    static let cashWithdrawal = "cash_withdrawal"
    static let reimbursementOrRefund = "reimbursement_or_refund"
    static let assetTransfer = "asset_transfer"
    static let unknown = "unknown"

    static let all: [String] = [
        income,
        committedOutflow,
        everydaySpend,
        fundBuilding,
        liabilityPayment,
        selfTransfer,
        cashWithdrawal,
        reimbursementOrRefund,
        assetTransfer,
        unknown
    ]
}

enum MoneCategoryFamily {
    static let income = "income"
    static let housing = "housing"
    static let utilities = "utilities"
    static let subscriptions = "subscriptions"
    static let insurance = "insurance"
    static let investments = "investments"
    static let debt = "debt"
    static let tax = "tax"
    static let familySupport = "family_support"
    static let householdHelp = "household_help"
    static let foodSnacks = "food_snacks"
    static let groceries = "groceries"
    static let transport = "transport"
    static let travel = "travel"
    static let medical = "medical"
    static let shopping = "shopping"
    static let education = "education"
    static let personalCare = "personal_care"
    static let lifestyleEntertainment = "lifestyle_entertainment"
    static let giftsDonations = "gifts_donations"
    static let localService = "local_service"
    static let localUpi = "local_upi"
    static let cash = "cash"
    static let transfers = "transfers"
    static let reimbursementsRefunds = "reimbursements_refunds"
    static let feesCharges = "fees_charges"
    static let businessWork = "business_work"
    static let assetTransfer = "asset_transfer"
    static let other = "other"
    static let unknown = "unknown"

    static let all: [String] = [
        income,
        housing,
        utilities,
        subscriptions,
        insurance,
        investments,
        debt,
        tax,
        familySupport,
        householdHelp,
        foodSnacks,
        groceries,
        transport,
        travel,
        medical,
        shopping,
        education,
        personalCare,
        lifestyleEntertainment,
        giftsDonations,
        localService,
        localUpi,
        cash,
        transfers,
        reimbursementsRefunds,
        feesCharges,
        businessWork,
        assetTransfer,
        other,
        unknown
    ]
}
