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
                HStack {
                    if isLoggedIn {
                        Color.clear.frame(width: 48, height: 48)
                    }
                    Spacer()
                    Text("mon\u{00E9}")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Color.monePrimary)
                    Spacer()
                    if isLoggedIn {
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
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Build your\nMoneyMap.")
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 24)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MoneSpacing.section) {
                        VStack(spacing: MoneSpacing.gutter) {
                            ForEach([SetupMethod.accountAggregator, .email, .manual], id: \.rawValue) { method in
                                let isAvailable = method == .accountAggregator
                                SetupOptionCard(
                                    method: method,
                                    isSelected: appVM.setupMethod == method,
                                    tag: appVM.setupMethod == method ? "Selected" : (isAvailable ? nil : "Coming soon")
                                ) {
                                    if isAvailable {
                                        appVM.setupMethod = method
                                    }
                                }
                                .opacity(isAvailable ? 1 : 0.45)
                            }
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.moneSecondary)
                            Text("moné stores only the final MoneyMap on your device. Raw data is never stored.")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                    .padding(.top, MoneSpacing.section)
                }

                HStack(spacing: MoneSpacing.gutter) {
                    MoneIconButton(icon: "chevron.left") {
                        appVM.goBack()
                    }
                    MonePrimaryButton(title: "Continue") {
                        appVM.advance()
                    }
                    .opacity(appVM.setupMethod == .accountAggregator ? 1 : 0.4)
                    .disabled(appVM.setupMethod != .accountAggregator)
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
        .environment(SessionViewModel())
}
