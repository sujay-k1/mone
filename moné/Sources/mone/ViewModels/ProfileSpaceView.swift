import SwiftUI

struct ProfileSpaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(AppViewModel.self) private var appVM

    @State private var showDeleteConfirmation = false
    @State private var showSignUpSheet = false
    
    private static let signUpDismissedKey = "mone.signUpDismissed"
    
    private var signUpPhone: String {
        appVM.verifiedPhone ?? sessionVM.profile?.phone ?? ""
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if sessionVM.isSignedIn {
                    signedInProfileContent
                } else {
                    guestProfileContent
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
            
            .sheet(isPresented: $showSignUpSheet) {
                SignUpSheet(
                    aaPhone: signUpPhone,
                    onDismissed: {
                        print("SIGNUP SHEET DISMISSED FROM PROFILE")
                        showSignUpSheet = false
                    },
                    onComplete: {
                        print("SIGNUP SHEET COMPLETED FROM PROFILE")
                        showSignUpSheet = false

                        Task {
                            await sessionVM.handleAuthSuccess()
                        }
                    }
                )
                .onAppear {
                    print("SIGNUP SHEET APPEARED FROM PROFILE with phone:", signUpPhone)
                }
            }
        }
    }

    private var signedInProfileContent: some View {
        VStack(spacing: 20) {
            signedInHeader

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
        }
    }

    private var guestProfileContent: some View {
        VStack(spacing: 20) {
            guestHeader

            VStack(spacing: 14) {
                Button {
                    showSignUpSheet = true
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Create your secure Moné account")
                                .font(.headline)
                                .foregroundStyle(Color.moneBackground)

                            Text("Back up your money map to the cloud and restore it safely when you switch devices.")
                                .font(.subheadline)
                                .foregroundStyle(Color.moneBackground.opacity(0.75))
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.moneBackground)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.monePrimary)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("Continue exploring without an account")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.moneSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var signedInHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.monePrimary)

            Text(sessionVM.displayName == "there" ? "Your profile" : sessionVM.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.monePrimary)

            Text("Manage your Moné account")
                .font(.subheadline)
                .foregroundStyle(Color.moneSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var guestHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.monePrimary)

            Text("Save your Moné progress")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.monePrimary)
                .multilineTextAlignment(.center)

            Text("Create an account to securely back up your financial profile, money map, and setup progress to the cloud.")
                .font(.body)
                .foregroundStyle(Color.moneSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Text("Your data stays protected with encrypted cloud storage.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.moneSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
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
