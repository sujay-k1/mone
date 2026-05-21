import Foundation

struct UPIQRPayload: Equatable {
    let rawValue: String
    let payeeVPA: String
    let payeeName: String?
    let merchantCode: String?
    let transactionRef: String?
    let transactionNote: String?
    let amount: Double?
    let currency: String?

    var displayName: String {
        let trimmedName = payeeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            return trimmedName
        }
        return payeeVPA
    }
}

struct UPIApp: Identifiable, Equatable {
    let id: String
    let displayName: String
    let scheme: String
    let paymentURLPrefix: String
    let systemIconName: String

    func paymentURL(payload: UPIQRPayload, amount: Double, note: String) -> URL? {
        var components = URLComponents(string: paymentURLPrefix)
        components?.queryItems = [
            URLQueryItem(name: "pa", value: payload.payeeVPA),
            URLQueryItem(name: "pn", value: payload.displayName),
            URLQueryItem(name: "am", value: String(format: "%.2f", amount)),
            URLQueryItem(name: "cu", value: payload.currency ?? "INR"),
            URLQueryItem(name: "tn", value: note.isEmpty ? payload.transactionNote : note),
            URLQueryItem(name: "tr", value: payload.transactionRef)
        ].compactMap { item in
            if let value = item.value, !value.isEmpty {
                return item
            }
            return nil
        }

        return components?.url
    }
}

struct PaymentGuidance: Equatable {
    enum Severity {
        case calm
        case watch
        case risk
        case supportive
    }

    let title: String
    let body: String
    let severity: Severity
    let metric: String?
}
