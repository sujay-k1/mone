import Foundation

enum RawPayloadImportError: Error {
    case fileNotFound(String)
    case invalidJSON(String)
    case invalidRoot(String)
}

final class RawPayloadImporter {

    // MARK: - Local bundled JSON import
    // Keep this for debug/fallback screens.
    func importPayload(
        personaId: PersonaId,
        fileName: String
    ) throws -> ImportResult {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw RawPayloadImportError.fileNotFound(fileName)
        }

        let data = try Data(contentsOf: url)

        return try importPayload(
            personaId: personaId,
            data: data,
            sourceName: fileName
        )
    }

    // MARK: - Data import
    // Use this when JSON comes from remote AA mock endpoint.
    func importPayload(
        personaId: PersonaId,
        data: Data,
        sourceName: String
    ) throws -> ImportResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw RawPayloadImportError.invalidRoot(sourceName)
        }

        return try importPayload(
            personaId: personaId,
            payloadRoot: root,
            sourceName: sourceName
        )
    }

    // MARK: - Parsed JSON root import
    // Use this when the Edge Function response already gives payload as [[String: Any]].
    func importPayload(
        personaId: PersonaId,
        payloadRoot root: [[String: Any]],
        sourceName: String
    ) throws -> ImportResult {
        var accounts: [FinancialAccount] = []
        var transactions: [RawTransaction] = []

        for fipEntry in root {
            let fipId =
                fipEntry["fipId"] as? String ??
                fipEntry["fipID"] as? String ??
                "unknown_fip"

            guard let dataItems = fipEntry["data"] as? [[String: Any]] else {
                continue
            }

            for item in dataItems {
                guard
                    let decryptedFI = item["decryptedFI"] as? [String: Any],
                    let account = decryptedFI["account"] as? [String: Any]
                else {
                    continue
                }

                let accountType =
                    decryptedFI["type"] as? String ??
                    account["type"] as? String ??
                    "unknown"

                let maskedAccountNumber =
                    item["maskedAccNumber"] as? String ??
                    decryptedFI["maskedAccNumber"] as? String ??
                    account["maskedAccNumber"] as? String

                let linkedAccRef =
                    decryptedFI["linkedAccRef"] as? String ??
                    account["linkedAccRef"] as? String ??
                    item["linkRefNumber"] as? String ??
                    UUID().uuidString

                let accountId = "\(personaId.rawValue)_\(linkedAccRef)"

                let summary = account["summary"] as? [String: Any]

                let currentBalance = parseDouble(summary?["currentBalance"])
                let currentValue = parseDouble(summary?["currentValue"])

                let financialAccount = FinancialAccount(
                    id: accountId,
                    personaId: personaId,
                    fipId: fipId,
                    accountType: accountType,
                    maskedAccountNumber: maskedAccountNumber,
                    currentBalance: currentBalance,
                    currentValue: currentValue
                )

                accounts.append(financialAccount)

                let accountTransactions =
                    ((account["transactions"] as? [String: Any])?["transaction"] as? [[String: Any]]) ?? []

                for txn in accountTransactions {
                    guard let txnId = txn["txnId"] as? String else {
                        continue
                    }

                    let type = txn["type"] as? String ?? "UNKNOWN"
                    let mode = txn["mode"] as? String ?? "UNKNOWN"
                    let amount = parseDouble(txn["amount"]) ?? 0
                    let narration = txn["narration"] as? String ?? ""

                    let valueDate = txn["valueDate"] as? String
                    let timestamp =
                        txn["transactionTimestamp"] as? String ??
                        txn["txnDate"] as? String

                    let currentBalance = parseDouble(txn["currentBalance"])

                    let transaction = RawTransaction(
                        id: txnId,
                        personaId: personaId,
                        accountId: accountId,
                        accountType: accountType,
                        type: type,
                        mode: mode,
                        amount: amount,
                        narration: narration,
                        valueDate: valueDate,
                        timestamp: timestamp,
                        currentBalance: currentBalance
                    )

                    transactions.append(transaction)
                }
            }
        }

        return ImportResult(
            personaId: personaId,
            accounts: accounts,
            transactions: transactions
        )
    }

    // MARK: - Helpers

    private func parseDouble(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }

        if let int = value as? Int {
            return Double(int)
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
    }
}
