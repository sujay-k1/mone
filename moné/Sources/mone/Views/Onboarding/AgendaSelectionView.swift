import SwiftUI
import Supabase

struct AgendaSelectionView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var showDeleteConfirmation = false

    private var isLoggedIn: Bool {
        supabase.auth.currentSession != nil
    }

    private func tagFor(_ agenda: AgendaType) -> String? {
        if appVM.primaryAgenda == agenda { return "Primary" }
        if appVM.secondaryAgenda == agenda { return "Secondary" }
        return nil
    }

    private func handleSelect(_ agenda: AgendaType) {
        if appVM.primaryAgenda == agenda {
            appVM.primaryAgenda = nil
            appVM.secondaryAgenda = nil
        } else if appVM.secondaryAgenda == agenda {
            appVM.secondaryAgenda = nil
        } else if appVM.primaryAgenda == nil {
            appVM.selectPrimary(agenda)
        } else {
            appVM.selectSecondary(agenda)
        }
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
                            Text("What do you want\nhelp with first?")
                                .font(.moneDisplayMd)
                                .foregroundStyle(Color.monePrimary)
                            Text("Pick one or two — this shapes your dashboard and nudges.")
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
                            ForEach(AgendaType.allCases) { agenda in
                                AgendaCard(
                                    agenda: agenda,
                                    isSelected: appVM.primaryAgenda == agenda || appVM.secondaryAgenda == agenda,
                                    tag: tagFor(agenda)
                                ) {
                                    handleSelect(agenda)
                                }
                            }
                            .padding(.bottom, -12)
                        }

                        if appVM.primaryAgenda != nil {
                            MoneTertiaryButton(title: "Clear selection") {
                                appVM.primaryAgenda = nil
                                appVM.secondaryAgenda = nil
                            }
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }

                HStack(spacing: MoneSpacing.gutter) {
                    if !isLoggedIn {
                        MoneIconButton(icon: "chevron.left") {
                            appVM.goBack()
                        }
                    }
                    MonePrimaryButton(title: "Continue") {
                        appVM.advance()
                    }
                    .opacity(appVM.primaryAgenda == nil ? 0.4 : 1)
                    .disabled(appVM.primaryAgenda == nil)
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, MoneSpacing.gutter)
                .padding(.bottom, 0)
                .background(Color.moneBackground)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.primaryAgenda)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appVM.secondaryAgenda)
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
    AgendaSelectionView()
        .environment(AppViewModel())
}
