import SwiftUI

struct NameOnboardingView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var fullName = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var isNameFocused: Bool

    private var isValid: Bool {
        fullName.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Color.clear.frame(width: 48, height: 48)
                Spacer()
                Text("mon\u{00E9}")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color.monePrimary)
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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What should we\ncall you?")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("This helps mon\u{00E9} personalize your\nexperience.")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("FULL NAME")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        VStack(spacing: 0) {
                            TextField("", text: $fullName, prompt: Text("e.g. Satoshi Nakamoto").foregroundColor(.moneTertiary))
                                .focused($isNameFocused)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.monePrimary)
                                .tint(Color.monePrimary)
                                .padding(.bottom, 14)

                            Rectangle()
                                .fill(Color.moneStrokeMid)
                                .frame(height: 1)
                        }
                    }

                    if let error = sessionVM.error {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }
            .contentShape(Rectangle())
            .onTapGesture { isNameFocused = false }

            MonePrimaryButton(title: sessionVM.isLoading ? "Saving..." : "Let\u{2019}s go") {
                Task { await sessionVM.saveName(fullName) }
            }
            .opacity(sessionVM.isLoading || !isValid ? 0.4 : 1)
            .disabled(sessionVM.isLoading || !isValid)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
        .background(Color.moneBackground.ignoresSafeArea())
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete account", role: .destructive) {
                Task { await sessionVM.deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your Moné account and profile data. This cannot be undone.")
        }
        .onAppear { isNameFocused = true }
        .onChange(of: fullName) { oldValue, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if newValue.count - oldValue.count >= 3 && trimmed.count >= 2 && !sessionVM.isLoading {
                Task { await sessionVM.saveName(fullName) }
            }
        }
    }
}
