import SwiftUI
import Supabase

struct SetupMethodView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var showDeleteConfirmation = false

    private var isLoggedIn: Bool {
        supabase.auth.currentSession != nil
    }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoggedIn {
                    HStack {
                        Spacer()
                        Menu {
                            Button("Log out", systemImage: "rectangle.portrait.and.arrow.right") {
                                Task { await sessionVM.signOut() }
                            }
                            .disabled(sessionVM.isLoading || sessionVM.isDeletingAccount)

                            Button(
                                sessionVM.isDeletingAccount ? "Deleting account..." : "Delete account",
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                showDeleteConfirmation = true
                            }
                            .disabled(sessionVM.isLoading || sessionVM.isDeletingAccount)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.moneTertiary)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, MoneSpacing.page)
                    .padding(.top, 8)
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MoneSpacing.section) {

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Build your\nMoney Map.")
                                .font(.moneDisplayMd)
                                .foregroundStyle(Color.monePrimary)
                            Text("Choose how moné learns about your finances.")
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.moneSecondary)

                            if let error = sessionVM.error {
                                Text(error)
                                    .font(.moneBodySm)
                                    .foregroundStyle(Color.moneRisk)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, isLoggedIn ? 20 : 60)

                        VStack(spacing: MoneSpacing.gutter) {
                            ForEach([SetupMethod.accountAggregator, .email, .manual], id: \.rawValue) { method in
                                SetupOptionCard(
                                    method: method,
                                    isSelected: appVM.setupMethod == method,
                                    tag: appVM.setupMethod == method ? "Selected" : nil
                                ) {
                                    appVM.setupMethod = method
                                }
                            }
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.moneSecondary)
                            Text("moné stores only the final Money Map on your device. Raw data is never stored.")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }

                HStack(spacing: MoneSpacing.gutter) {
                    MoneIconButton(icon: "chevron.left") {
                        appVM.goBack()
                    }
                    MonePrimaryButton(title: "Continue") {
                        appVM.advance()
                    }
                    .opacity(appVM.setupMethod == nil ? 0.4 : 1)
                    .disabled(appVM.setupMethod == nil)
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, MoneSpacing.gutter)
                .padding(.bottom, 0)
                .background(Color.moneBackground)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.setupMethod)
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete account", role: .destructive) {
                Task { await sessionVM.deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your Moné account and profile data. This cannot be undone.")
        }
    }
}

#Preview {
    SetupMethodView()
        .environment(AppViewModel())
}
