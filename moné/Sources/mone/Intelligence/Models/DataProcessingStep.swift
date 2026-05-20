import Foundation

enum DataProcessingStep: String, CaseIterable, Identifiable {
    case fetchingAccountData = "Fetching account data"
    case readingAccounts = "Reading accounts"
    case readingTransactions = "Reading transactions"
    case categorisingTransactions = "Categorising transactions"
    case resolvingUnclearItems = "Resolving unclear items"
    case buildingInsights = "Building insights"
    case savingResults = "Saving results"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .fetchingAccountData:
            return "Retrieving your financial data after OTP verification."
        case .readingAccounts:
            return "Identifying your linked accounts and balances."
        case .readingTransactions:
            return "Organising transactions across accounts and months."
        case .categorisingTransactions:
            return "Sorting income, spends, transfers, investments, and obligations."
        case .resolvingUnclearItems:
            return "Checking ambiguous transactions for better accuracy."
        case .buildingInsights:
            return "Preparing your dashboard, trends, and MoneyMap."
        case .savingResults:
            return "Saving your processed insights on this device."
        }
    }
}
