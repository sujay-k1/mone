import Foundation
import SwiftUI

enum DashboardNudgeID: String, CaseIterable {
    case signUp = "sign_up"
    case goalSetting = "goal_setting"
    case notifications = "notifications"
    case smsPermission = "sms_permission"
}

struct DashboardNudge: Identifiable {
    let id: DashboardNudgeID
    let title: String
    let message: String
    let primaryActionTitle: String
    let iconName: String
}

struct DashboardNudgeContext {
    let isSignedIn: Bool
    let hasAnyGoal: Bool
    let hasNotificationPermission: Bool
    let hasSMSPermission: Bool
}

enum DashboardNudgeKeys {
    static let dismissedDashboardNudges = "mone.dismissedDashboardNudges"
    static let dashboardNudgeRotationIndex = "mone.dashboardNudgeRotationIndex"
    static let notificationPermissionGranted = "mone.notificationPermissionGranted"
    static let smsPermissionConnected = "mone.smsPermissionConnected"
}

final class DashboardNudgeStore {
    func dismiss(_ id: DashboardNudgeID) {
        var dismissed = dismissedIDs()
        dismissed.insert(id.rawValue)
        UserDefaults.standard.set(Array(dismissed), forKey: DashboardNudgeKeys.dismissedDashboardNudges)
    }

    func nextEligibleNudge(context: DashboardNudgeContext) -> DashboardNudge? {
        let dismissed = dismissedIDs()

        let eligible = allNudges(context: context)
            .filter { !dismissed.contains($0.id.rawValue) }

        guard !eligible.isEmpty else {
            return nil
        }

        if let signUpNudge = eligible.first(where: { $0.id == .signUp }) {
            return signUpNudge
        }

        let currentIndex = UserDefaults.standard.integer(forKey: DashboardNudgeKeys.dashboardNudgeRotationIndex)
        let selected = eligible[currentIndex % eligible.count]

        UserDefaults.standard.set(currentIndex + 1, forKey: DashboardNudgeKeys.dashboardNudgeRotationIndex)

        return selected
    }

    private func dismissedIDs() -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: DashboardNudgeKeys.dismissedDashboardNudges) ?? []
        return Set(values)
    }

    private func allNudges(context: DashboardNudgeContext) -> [DashboardNudge] {
        var nudges: [DashboardNudge] = []

        if !context.isSignedIn {
            nudges.append(
                DashboardNudge(
                    id: .signUp,
                    title: "Keep your Money Map safe",
                    message: "Don't lose your progress and financial health, sign up to keep your data encrypted on cloud.",
                    primaryActionTitle: "Sign up",
                    iconName: "checkmark.shield"
                )
            )
        }

        if !context.hasAnyGoal {
            nudges.append(
                DashboardNudge(
                    id: .goalSetting,
                    title: "Give your money a direction",
                    message: "Set a financial goal so Moné can translate your spending, savings, and surplus into a clear monthly plan.",
                    primaryActionTitle: "Set a goal",
                    iconName: "dot.scope"
                )
            )
        }

        if !context.hasNotificationPermission {
            nudges.append(
                DashboardNudge(
                    id: .notifications,
                    title: "Stay ahead of changes",
                    message: "Get timely nudges about trends, progress, upcoming pressure points",
                    primaryActionTitle: "Enable alerts",
                    iconName: "bell.and.waves.left.and.right"
                )
            )
        }

        if !context.hasSMSPermission {
            nudges.append(
                DashboardNudge(
                    id: .smsPermission,
                    title: "Get real-time spend nudges",
                    message: "Let moné keep an eye on the transactions and transaction requests for efficient monitoring",
                    primaryActionTitle: "Connect SMS",
                    iconName: "ellipsis.message"
                )
            )
        }

        return nudges
    }
}

extension Notification.Name {
    static let moneOpenGoalSetup = Notification.Name("mone.openGoalSetup")
    static let moneOpenSMSPermission = Notification.Name("mone.openSMSPermission")
}
