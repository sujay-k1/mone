import SwiftUI

struct DummyAAConsentView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showPhoneOTP = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("mon\u{00E9}")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color.monePrimary)
                Spacer()
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("Here's what \nhappens next...")
                    .font(.moneDisplayMd)
                    .foregroundStyle(Color.monePrimary)

                Text("OneMoney shares your encrypted financial statements linked to your PAN directly to you.")
                    .font(.moneBodyLg)
                    .foregroundStyle(Color.moneSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, 24)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    // What we request
                    VStack(alignment: .leading, spacing: 14) {
                        Text("WHAT ARE WE REQUESTING")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        ConsentItem(icon: "list.bullet.rectangle", text: "Bank account transactions")
                        ConsentItem(icon: "indianrupeesign.circle", text: "Account balances and summaries")
                        ConsentItem(icon: "chart.line.uptrend.xyaxis", text: "Investment and deposit accounts when present")
                        ConsentItem(icon: "creditcard", text: "Card and device-finance context")
                    }

                    // What we build
                    VStack(alignment: .leading, spacing: 14) {
                        Text("WHAT MON\u{00C9} BUILDS FROM THIS")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        ConsentItem(icon: "gauge.with.needle", text: "Safe-to-spend estimate")
                        ConsentItem(icon: "arrow.triangle.2.circlepath", text: "Fixed commitments, EMIs, and recurring payments")
                        ConsentItem(icon: "chart.bar", text: "Income and cashflow patterns")
                        ConsentItem(icon: "flag", text: "Goal risk and spending signals")
                    }

                    // Privacy note
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.moneHealthy)

                        Text("Your data is stored and processed locally, on device. mon\u{00E9} does not read the data or store it.")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneTertiary)
                    }

                    .padding(.vertical, MoneSpacing.cardSm)
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.vertical, MoneSpacing.section)
            }

            HStack(spacing: MoneSpacing.gutter) {
                MoneIconButton(icon: "chevron.left") {
                    appVM.goBack()
                }
                MonePrimaryButton(title: "Fetch your details") {
                    showPhoneOTP = true
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, 0)
        }
        .background(Color.moneBackground.ignoresSafeArea())
        .onAppear {
            openFetchDetailsSheetIfRequested()
        }
        .onChange(of: appVM.shouldOpenAAFetchDetailsSheet) { _, _ in
            openFetchDetailsSheetIfRequested()
        }
        .sheet(isPresented: $showPhoneOTP) {
            PhoneOTPSheet(
                title: "Gather your \nFinancial Institutions",
                subtitle: "OneMoney will enlist all the banks, insurance providers and other financial institutions you have ever dealt with.",
                showConsent: true
            ) { phone in
                appVM.verifiedPhone = phone
                appVM.onboardingStep = .aaFetching
            }
        }
    }

    private func openFetchDetailsSheetIfRequested() {
        guard appVM.shouldOpenAAFetchDetailsSheet else { return }
        appVM.shouldOpenAAFetchDetailsSheet = false
        showPhoneOTP = true
    }
}

// MARK: - Consent Item

private struct ConsentItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.moneSecondary)
                .frame(width: 24, height: 24)

            Text(text)
                .font(.moneBodyMd)
                .foregroundStyle(Color.monePrimary)
        }
    }
}
#Preview {
    DummyAAConsentView()
        .environment(AppViewModel())
        .environment(SessionViewModel())
}
