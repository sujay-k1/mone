import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            switch appVM.primaryAgenda ?? .controlSpending {
            case .controlSpending:   SpendingDashboardView()
            case .planGoals:         GoalsDashboardView()
            case .understandPicture: FinancialPictureDashboardView()
            }
        }
    }
}

// MARK: - Shared Dashboard Header

struct DashboardHeader: View {
    @Environment(AppViewModel.self) private var appVM
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("moné")
                    .font(.moneLabelCaps)
                    .tracking(1.5)
                    .foregroundStyle(Color.moneTertiary)
                Text(title)
                    .font(.moneHLMd)
                    .foregroundStyle(Color.monePrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                }
            }
            Spacer()
            // Health status dot
            let status = appVM.healthReport.overallStatus
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .strokeBorder(status.color.opacity(0.3), lineWidth: 4)
                )
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppViewModel())
}
