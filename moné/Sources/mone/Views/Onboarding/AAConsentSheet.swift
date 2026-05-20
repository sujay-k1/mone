import SwiftUI
import SafariServices

struct AAConsentSheet: View {
    let onVerified: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var consentAccepted = false
    @State private var showPrivacyPolicy = false
    @State private var showPhoneOTP = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MoneSpacing.section) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Data consent")
                                .font(.moneDisplayMd)
                                .foregroundStyle(Color.monePrimary)
                            Text("We need your consent before fetching financial data via the Account Aggregator framework.")
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.moneSecondary)
                        }
                        .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("WHAT WE WILL ACCESS")
                                .font(.moneLabelCaps)
                                .tracking(2)
                                .foregroundStyle(Color.moneTertiary)

                            ConsentRow(icon: "list.bullet.rectangle", text: "Bank account transactions")
                            ConsentRow(icon: "indianrupeesign.circle", text: "Account balances and summaries")
                            ConsentRow(icon: "chart.line.uptrend.xyaxis", text: "Investment and deposit accounts")
                            ConsentRow(icon: "creditcard", text: "Card and device-finance context")
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.moneHealthy)
                            Text("Your data is processed on-device. mon\u{00E9} does not read or store raw financial data.")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneTertiary)
                        }

                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                consentAccepted.toggle()
                            } label: {
                                Image(systemName: consentAccepted ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 22))
                                    .foregroundStyle(consentAccepted ? Color.moneActionFill : Color.moneStrokeMid)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("I agree to the data fetch and processing described above.")
                                    .font(.moneBodyMd)
                                    .foregroundStyle(Color.monePrimary)

                                Button {
                                    showPrivacyPolicy = true
                                } label: {
                                    Text("Read the Terms & Conditions")
                                        .font(.moneBodySm)
                                        .foregroundStyle(Color.moneActionFill)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }

                MonePrimaryButton(title: "Verify with phone number") {
                    showPhoneOTP = true
                }
                .opacity(consentAccepted ? 1 : 0.4)
                .disabled(!consentAccepted)
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, MoneSpacing.gutter)
                .padding(.bottom, MoneSpacing.gutter)
            }
            .background(Color.moneBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.moneTertiary)
                }
            }
            .sheet(isPresented: $showPhoneOTP) {
                PhoneOTPSheet(
                    title: "Verify your\nphone number",
                    subtitle: "We\u{2019}ll verify your number before the demo Account Aggregator fetch starts."
                ) { phone in
                    dismiss()
                    onVerified(phone)
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                SafariView(url: URL(string: "https://www.onemoney.in/tandc.html")!)
            }
        }
    }
}

// MARK: - Consent Row

private struct ConsentRow: View {
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

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = UIColor(red: 0x0E/255, green: 0x0E/255, blue: 0x0E/255, alpha: 1)
        vc.preferredControlTintColor = UIColor(red: 0xE5/255, green: 0xE2/255, blue: 0xE0/255, alpha: 1)
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
