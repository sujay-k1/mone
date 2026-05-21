import Foundation
import UIKit

@MainActor
enum UPIAppDiscoveryService {

    static let supportedApps: [UPIApp] = [
        UPIApp(
            id: "gpay",
            displayName: "Google Pay",
            scheme: "tez",
            paymentURLPrefix: "tez://upi/pay",
            systemIconName: "g.circle.fill"
        ),
        UPIApp(
            id: "phonepe",
            displayName: "PhonePe",
            scheme: "phonepe",
            paymentURLPrefix: "phonepe://pay",
            systemIconName: "p.circle.fill"
        ),
        UPIApp(
            id: "paytm",
            displayName: "Paytm",
            scheme: "paytmmp",
            paymentURLPrefix: "paytmmp://pay",
            systemIconName: "p.square.fill"
        ),
        UPIApp(
            id: "bhim",
            displayName: "BHIM",
            scheme: "bhim",
            paymentURLPrefix: "bhim://upi/pay",
            systemIconName: "b.circle.fill"
        ),
        UPIApp(
            id: "amazonpay",
            displayName: "Amazon Pay",
            scheme: "amazonpay",
            paymentURLPrefix: "amazonpay://upi/pay",
            systemIconName: "a.circle.fill"
        ),
        UPIApp(
            id: "cred",
            displayName: "CRED",
            scheme: "cred",
            paymentURLPrefix: "cred://upi/pay",
            systemIconName: "c.circle.fill"
        ),
        UPIApp(
            id: "whatsapp",
            displayName: "WhatsApp",
            scheme: "whatsapp",
            paymentURLPrefix: "whatsapp://upi/pay",
            systemIconName: "message.circle.fill"
        )
    ]

    static func installedApps() -> [UPIApp] {
        supportedApps.filter { app in
            guard let url = URL(string: "\(app.scheme)://") else {
                return false
            }
            return UIApplication.shared.canOpenURL(url)
        }
    }
}
