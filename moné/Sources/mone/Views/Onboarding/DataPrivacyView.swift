import SwiftUI

struct DataPrivacyView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MoneSpacing.section) {

                        // Header
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your money data,\nyour choice.")
                                .font(.moneDisplayMd)
                                .foregroundStyle(Color.monePrimary)
                            Text("Choose how moné stores your Money Map.")
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.moneSecondary)
                        }
                        .padding(.top, 60)

                        // Options
                        VStack(spacing: MoneSpacing.gutter) {
                            
                            PrivacyOptionCard(
                                icon: "lock.icloud",
                                title: "Sign-up securely on moné",
                                bullets: [
                                    "Restore on another device",
                                    "Encrypted — only you can read it",
                                ],
                                isRecommended: false,
                                isSelected: appVM.storageMode == .encryptedBackup
                            ) {
                                appVM.storageMode = .encryptedBackup
                            }
                            
                            PrivacyOptionCard(
                                icon: "iphone",
                                title: "Skip sign-up",
                                bullets: [
                                    "Data stays on this iPhone",
                                    "Third-party access will require respective sign-in"
                                ],
                                isRecommended: false,
                                isSelected: appVM.storageMode == .local,
                                warning: appVM.storageMode == .local
                                    ? "Deleting the app or switching phones will remove your Money Map."
                                    : nil
                            ) {
                                appVM.storageMode = .local
                            }
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }

                // Sticky bottom CTAs
                HStack(spacing: MoneSpacing.gutter) {
                    MoneIconButton(icon: "chevron.left") {
                        appVM.goBack()
                    }
                    MonePrimaryButton(title: "Continue") {
                        appVM.advance()
                    }
                    .opacity(appVM.storageMode == nil ? 0.4 : 1)
                    .disabled(appVM.storageMode == nil)
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, MoneSpacing.gutter)
                .padding(.bottom, 0)
                .background(Color.moneBackground)
            }
        }
    }
}

private struct PrivacyOptionCard: View {
    let icon: String
    let title: String
    let bullets: [String]
    let isRecommended: Bool
    var isSelected: Bool = false
    var warning: String? = nil
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                HStack(spacing: MoneSpacing.gutter) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.moneActionFill.opacity(0.15) : Color.moneSurfaceEl)
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.moneHLSm)
                            .foregroundStyle(Color.monePrimary)

                        ForEach(bullets, id: \.self) { bullet in
                            HStack(alignment: .center, spacing: 8) {
                                Text("·")
                                    .foregroundStyle(Color.moneTertiary)
                                Text(bullet)
                                    .font(.moneBodySm)
                                    .foregroundStyle(Color.moneSecondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? Color.moneActionFill : Color.moneTertiary)
                }

                if let warning {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.moneWatch)
                        Text(warning)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(MoneSpacing.cardSm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.moneWatchBg)
                    .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                }
            }
            .padding(MoneSpacing.cardSm)
            .background(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.moneStrokeBright : Color.moneStroke,
                        lineWidth: 1
                    )
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: warning)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DataPrivacyView()
        .environment(AppViewModel())
}
