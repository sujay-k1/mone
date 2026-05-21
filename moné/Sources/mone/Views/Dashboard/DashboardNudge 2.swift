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

final class DashboardNudgeStore {
    private let dismissedKey = "mone.dismissedDashboardNudges"
    private let rotationKey = "mone.dashboardNudgeRotationIndex"

    func dismiss(_ id: DashboardNudgeID) {
        var dismissed = dismissedIDs()
        dismissed.insert(id.rawValue)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedKey)
    }

    func nextEligibleNudge(context: DashboardNudgeContext) -> DashboardNudge? {
        let dismissed = dismissedIDs()

        let eligible = allNudges(context: context)
            .filter { !dismissed.contains($0.id.rawValue) }

        guard !eligible.isEmpty else {
            return nil
        }

        let currentIndex = UserDefaults.standard.integer(forKey: rotationKey)
        let selected = eligible[currentIndex % eligible.count]

        UserDefaults.standard.set(currentIndex + 1, forKey: rotationKey)

        return selected
    }

    private func dismissedIDs() -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
        return Set(values)
    }

    private func allNudges(context: DashboardNudgeContext) -> [DashboardNudge] {
        var nudges: [DashboardNudge] = []

        if !context.isSignedIn {
            nudges.append(
                DashboardNudge(
                    id: .signUp,
                    title: "Keep your Money Map safe",
                    message: "Create an account to keep your setup, insights, goals, and preferences available across sessions.",
                    primaryActionTitle: "Sign up",
                    iconName: "person.crop.circle.badge.plus"
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
                    iconName: "target"
                )
            )
        }

        if !context.hasNotificationPermission {
            nudges.append(
                DashboardNudge(
                    id: .notifications,
                    title: "Stay ahead of changes",
                    message: "Enable notifications to get timely alerts about new trends, progress, unusual spends, and upcoming pressure points.",
                    primaryActionTitle: "Enable alerts",
                    iconName: "bell.badge"
                )
            )
        }

        if !context.hasSMSPermission {
            nudges.append(
                DashboardNudge(
                    id: .smsPermission,
                    title: "Get real-time spend nudges",
                    message: "Connect SMS signals so Moné can detect fresh spends sooner and nudge you before habits become patterns.",
                    primaryActionTitle: "Connect SMS",
                    iconName: "message.badge"
                )
            )
        }

        return nudges
    }
}
