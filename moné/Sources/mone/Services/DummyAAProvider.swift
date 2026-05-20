import Foundation

// MARK: - AA Payload Types

struct AAPayload: Codable {
    let fips: [AAFIPData]

    init(fips: [AAFIPData]) {
        self.fips = fips
    }

    init(from decoder: Decoder) throws {
        if let fips = try? [AAFIPData](from: decoder) {
            self.fips = fips
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fips = try container.decode([AAFIPData].self, forKey: .fips)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fips, forKey: .fips)
    }

    private enum CodingKeys: String, CodingKey {
        case fips
    }
}

struct AAFIPData: Codable {
    let fipID: String
    let data: [AADataItem]
}

struct AADataItem: Codable {
    let decryptedFI: AADecryptedFI
    let linkRefNumber: String
    let maskedAccNumber: String
}

struct AADecryptedFI: Codable {
    let type: String
    let account: AAAccount
}

struct AAAccount: Codable {
    let type: String
    let version: String
    let linkedAccRef: String
    let maskedAccNumber: String
    let profile: AAProfile
    let summary: AAAccountSummary
    let transactions: AATransactionSet
}

struct AAProfile: Codable {
    let holders: AAHolders
}

struct AAHolders: Codable {
    let type: String
    let holder: [AAHolder]
}

struct AAHolder: Codable {
    let name: String?
    let mobile: String?
    let email: String?
}

struct AAAccountSummary: Codable {
    let type: String?
    let branch: String?
    let status: String?
    let currency: String?
    let ifscCode: String?
    let openingDate: String?
    let currentBalance: String?
    let currentValue: String?
    let openingValue: String?
    let investmentValue: String?
    let principalAmount: String?
    let maturityAmount: String?
    let prematureWithdrawalAmount: String?
    let closurePayoutAmount: String?
    let penaltyAmount: String?

    var sourceBalance: Double {
        double(currentBalance) ??
        double(currentValue) ??
        double(closurePayoutAmount) ??
        0
    }

    private func double(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value)
    }
}

struct AATransactionSet: Codable {
    let startDate: String
    let endDate: String
    let transaction: [AATransaction]
}

struct AATransaction: Codable {
    let txnId: String
    let type: String
    let mode: String
    let amount: String
    let narration: String
    let reference: String
    let valueDate: String
    let currentBalance: String
    let transactionTimestamp: String
}

// MARK: - Source Bundle

struct SyntheticAAResponse {
    let provider: String
    let personaId: String
    let displayName: String
    let phone: String
    let fetchedAt: Date
    let asOfDate: Date
    let aaPayload: AAPayload
    let sourceBundle: SyntheticSourceBundle
}

struct SyntheticSourceBundle {
    let accounts: CSVTable
    let transactions: CSVTable
    let monthlyCashflow: CSVTable
    let modeSpendingSummary: CSVTable
    let creditCardStatement: JSONValue
    let creditCardSummary: CSVTable
    let creditCardTransactions: CSVTable
    let deviceFinanceSource: JSONValue
}

struct CSVTable {
    let columns: [String]
    let rows: [[String: String]]
}

enum JSONValue {
    case object([String: Any])
    case array([Any])
}

// MARK: - AA Provider Protocol

protocol AAProvider {
    func fetchFinancialData(phone: String) async throws -> SyntheticAAResponse
}

enum DemoPhoneState: Equatable {
    case aarav
    case priyaNotWired
    case unsupported
}

enum AAProviderError: LocalizedError, Equatable {
    case priyaNotWired
    case unsupportedPhone
    case missingSourceFile(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .priyaNotWired:
            return "Priya demo data is not wired yet. Please use Aarav's demo number for now."
        case .unsupportedPhone:
            return "This phone number is not part of the demo. Please use 8828290489 for Aarav."
        case .missingSourceFile(let name):
            return "The synthetic source bundle is missing \(name)."
        case .decodeFailed(let name):
            return "Could not decode \(name) from the synthetic source bundle."
        }
    }
}

// MARK: - Dummy AA Provider

final class DummyAAProvider: AAProvider {
    static let shared = DummyAAProvider()

    static let aaravPhone = "8828290489"
    static let priyaPhone = "7304893952"
    static let aaravDatasetId = "aarav_spend_control_rash_decisions"

    static func demoState(for phone: String) -> DemoPhoneState {
        switch normalizedPhone(phone) {
        case aaravPhone: return .aarav
        case priyaPhone: return .priyaNotWired
        default: return .unsupported
        }
    }

    static func personaName(for phone: String) -> String? {
        switch demoState(for: phone) {
        case .aarav: return "Aarav"
        case .priyaNotWired: return "Priya"
        case .unsupported: return nil
        }
    }

    static func isSupported(phone: String) -> Bool {
        demoState(for: phone) != .unsupported
    }

    func fetchFinancialData(phone: String) async throws -> SyntheticAAResponse {
        switch Self.demoState(for: phone) {
        case .aarav:
            return try Self.loadAaravBundle(phone: Self.normalizedPhone(phone))
        case .priyaNotWired:
            throw AAProviderError.priyaNotWired
        case .unsupported:
            throw AAProviderError.unsupportedPhone
        }
    }

    private static func loadAaravBundle(phone: String) throws -> SyntheticAAResponse {
        let rawPayloadData = try data(for: "raw_payload", extension: "json")
        let payload = try decode(AAPayload.self, from: rawPayloadData, name: "raw_payload.json")

        let sourceBundle = SyntheticSourceBundle(
            accounts: try csvTable(named: "accounts"),
            transactions: try csvTable(named: "transactions"),
            monthlyCashflow: try csvTable(named: "monthly_cashflow"),
            modeSpendingSummary: try csvTable(named: "mode_spending_summary"),
            creditCardStatement: try jsonValue(named: "credit_card_statement"),
            creditCardSummary: try csvTable(named: "credit_card_summary"),
            creditCardTransactions: try csvTable(named: "credit_card_transactions"),
            deviceFinanceSource: try jsonValue(named: "device_finance_source")
        )

        return SyntheticAAResponse(
            provider: "synthetic-aa",
            personaId: "aarav",
            displayName: "Aarav",
            phone: phone,
            fetchedAt: Date(),
            asOfDate: fixedAsOfDate(),
            aaPayload: payload,
            sourceBundle: sourceBundle
        )
    }

    private static func normalizedPhone(_ phone: String) -> String {
        String(phone.filter(\.isNumber).suffix(10))
    }

    private static func fixedAsOfDate() -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Kolkata")
        components.year = 2026
        components.month = 5
        components.day = 31
        components.hour = 12
        return components.date ?? Date()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, name: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AAProviderError.decodeFailed(name)
        }
    }

    private static func jsonValue(named name: String) throws -> JSONValue {
        let data = try data(for: name, extension: "json")
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            if let dictionary = object as? [String: Any] { return .object(dictionary) }
            if let array = object as? [Any] { return .array(array) }
            throw AAProviderError.decodeFailed("\(name).json")
        } catch let error as AAProviderError {
            throw error
        } catch {
            throw AAProviderError.decodeFailed("\(name).json")
        }
    }

    private static func csvTable(named name: String) throws -> CSVTable {
        let data = try data(for: name, extension: "csv")
        guard let text = String(data: data, encoding: .utf8) else {
            throw AAProviderError.decodeFailed("\(name).csv")
        }

        let rows = parseCSV(text)
        guard let header = rows.first else {
            return CSVTable(columns: [], rows: [])
        }

        let records = rows.dropFirst().map { values in
            Dictionary(uniqueKeysWithValues: header.enumerated().map { index, key in
                (key, index < values.count ? values[index] : "")
            })
        }
        return CSVTable(columns: header, rows: records)
    }

    private static func data(for name: String, extension ext: String) throws -> Data {
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: ext,
            subdirectory: aaravDatasetId
        ) {
            return try Data(contentsOf: url)
        }

        if let url = findBundledFile(named: "\(name).\(ext)") {
            return try Data(contentsOf: url)
        }

        let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("data/synthetic/output")
            .appendingPathComponent(aaravDatasetId)
            .appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: repoURL.path) {
            return try Data(contentsOf: repoURL)
        }

        throw AAProviderError.missingSourceFile("\(name).\(ext)")
    }

    private static func findBundledFile(named fileName: String) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: nil
        ) else { return nil }

        for case let url as URL in enumerator where url.lastPathComponent == fileName {
            if url.path.contains(aaravDatasetId) {
                return url
            }
        }
        return nil
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()

        while let char = iterator.next() {
            if char == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        if next == "," {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                row.append(field)
                field = ""
            } else if char == "\n" && !inQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if char != "\r" {
                field.append(char)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}
