import Foundation

enum UPIQRParser {
    static func parse(_ rawValue: String) -> UPIQRPayload? {
        guard
            let components = URLComponents(string: rawValue),
            components.scheme?.lowercased() == "upi",
            components.host?.lowercased() == "pay"
        else {
            return nil
        }

        let items = components.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first(where: { $0.name.lowercased() == name.lowercased() })?.value?
                .removingPercentEncoding
        }

        guard let payeeVPA = value("pa"), !payeeVPA.isEmpty else {
            return nil
        }

        let amount = value("am").flatMap { Double($0) }

        return UPIQRPayload(
            rawValue: rawValue,
            payeeVPA: payeeVPA,
            payeeName: value("pn"),
            merchantCode: value("mc"),
            transactionRef: value("tr"),
            transactionNote: value("tn"),
            amount: amount,
            currency: value("cu") ?? "INR"
        )
    }
}
