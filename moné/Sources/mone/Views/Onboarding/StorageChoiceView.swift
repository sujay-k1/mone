import SwiftUI

struct StorageChoiceView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var showAuth = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Money Map\nis ready.")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("Choose how mon\u{00E9} should keep this analysis. Account creation stays optional.")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 60)

                    VStack(spacing: MoneSpacing.gutter) {
                        StorageOptionCard(
                            icon: "lock.shield",
                            title: "Create account and store encrypted data",
                            detail: "Use the existing encrypted backup path so you can restore your Money Map later.",
                            badge: "Optional"
                        ) {
                            appVM.storageMode = .encryptedBackup
                            if supabase.auth.currentSession == nil {
                                showAuth = true
                            } else {
                                appVM.advance()
                            }
                        }

                        StorageOptionCard(
                            icon: "iphone",
                            title: "Continue locally",
                            detail: "Keep this demo Money Map on this device. Deleting the app or changing phones may lose it.",
                            badge: nil
                        ) {
                            appVM.storageMode = .local
                            appVM.advance()
                        }
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.moneSecondary)
                        Text("Source AA files are processed into derived objects. Expected fixture files are test oracles and are not loaded by the app.")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneTertiary)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
        .background(Color.moneBackground.ignoresSafeArea())
        .sheet(isPresented: $showAuth) {
            AuthView(
                onAuthComplete: {
                    showAuth = false
                    Task { await sessionVM.handleAuthSuccess() }
                    appVM.advance()
                },
                showBackButton: false
            )
        }
    }
}

private struct StorageOptionCard: View {
    let icon: String
    let title: String
    let detail: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: MoneSpacing.gutter) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.monePrimary)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.moneLabelCaps)
                                .tracking(0.8)
                                .foregroundStyle(Color.moneActionFill)
                        }
                    }
                    Text(detail)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.moneTertiary)
            }
            .padding(MoneSpacing.cardSm)
            .moneCard()
        }
        .buttonStyle(.plain)
    }
}

struct DashboardTourView: View {
    @Environment(AppViewModel.self) private var appVM
    @AppStorage("mone.dashboardTourCompleted") private var tourCompleted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: MoneSpacing.section) {
                Text("Read this as a\ncontrol room.")
                    .font(.moneDisplayMd)
                    .foregroundStyle(Color.monePrimary)

                VStack(alignment: .leading, spacing: 16) {
                    TourRow(icon: "gauge.with.needle", text: "Safe-to-spend is not your bank balance. It reserves commitments, EMIs, and goals first.")
                    TourRow(icon: "creditcard", text: "Card and EMI pressure is treated as future debt, not fresh spending room.")
                    TourRow(icon: "bell.badge", text: "Only high-severity moments interrupt. Leaks stay as dashboard or weekly signals.")
                }
            }
            .padding(.horizontal, MoneSpacing.page)

            Spacer()

            MonePrimaryButton(title: "Go to dashboard") {
                tourCompleted = true
                appVM.advance()
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.bottom, MoneSpacing.gutter)
        }
        .background(Color.moneBackground.ignoresSafeArea())
        .onAppear {
            if tourCompleted {
                appVM.advance()
            }
        }
    }
}

private struct TourRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.moneSecondary)
                .frame(width: 24)
            Text(text)
                .font(.moneBodyMd)
                .foregroundStyle(Color.moneSecondary)
        }
    }
}
