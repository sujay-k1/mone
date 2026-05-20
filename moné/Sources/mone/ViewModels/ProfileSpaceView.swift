import SwiftUI

struct ProfileSpaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(AppViewModel.self) private var appVM

    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header

                VStack(spacing: 12) {
                    profileRow(
                        title: "Setup account aggregator",
                        subtitle: "Connect or refresh your financial accounts",
                        systemImage: "link.circle",
                        isDestructive: false
                    ) {
                        openAccountAggregatorSetup()
                    }

                    profileRow(
                        title: "Logout",
                        subtitle: "Sign out from this device",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        isDestructive: false
                    ) {
                        Task {
                            await sessionVM.signOut()
                            dismiss()
                        }
                    }

                    profileRow(
                        title: sessionVM.isDeletingAccount ? "Deleting account..." : "Delete account",
                        subtitle: "Remove this profile and local demo data",
                        systemImage: "trash",
                        isDestructive: true
                    ) {
                        showDeleteConfirmation = true
                    }
                    .disabled(sessionVM.isDeletingAccount)
                    .opacity(sessionVM.isDeletingAccount ? 0.6 : 1)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.moneBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) {
                    Task {
                        await sessionVM.deleteAccount()
                        dismiss()
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete your account and return you to onboarding.")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.monePrimary)

            Text(sessionVM.displayName == "there" ? "Your profile" : sessionVM.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.monePrimary)

            Text("Manage your Moné account")
                .font(.subheadline)
                .foregroundStyle(Color.monePrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func profileRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isDestructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDestructive ? .red : Color.monePrimary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isDestructive ? .red : Color.monePrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.moneSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.moneSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.moneSurface)
            )
        }
        .buttonStyle(.plain)
    }

    private func openAccountAggregatorSetup() {
        sessionVM.shouldForceWelcomeOnboarding = false
        sessionVM.nextOnboardingStep = .aaConsent
        appVM.startAuthenticatedOnboarding(at: .aaConsent)
        sessionVM.route = .onboarding
        dismiss()
    }
}
