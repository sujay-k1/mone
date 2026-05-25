import SwiftUI

struct PhoneOTPSheet: View {
    enum Step { case phoneEntry, otpEntry, panEntry, accountSelection, consentOTP }

    let title: String
    let subtitle: String
    var showConsent: Bool = false
    let onVerified: (String) -> Void

    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = PhoneVerificationVM()
    @State private var step: Step = .phoneEntry
    @State private var consentAccepted = false
    @State private var showPrivacyPolicy = false
    @State private var showToast = false
    @State private var pan = ""
    @State private var panError: String?
    @State private var panLoading = false
    @State private var showLeaveAlert = false
    @State private var accounts: [FIAccount] = []
    @State private var isEditingAccounts = false
    @State private var consentOTPAccepted = false
    @State private var consentOTP = ""
    @State private var consentOTPError: String?
    @State private var consentOTPLoading = false
    @State private var consentOTPResendCountdown: Int = 30
    @State private var consentOTPTimerGeneration = UUID()
    @FocusState private var isPhoneFocused: Bool
    @FocusState private var isPanFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    switch step {
                    case .phoneEntry:
                        phoneEntryContent
                    case .otpEntry:
                        otpEntryContent
                    case .panEntry:
                        panEntryContent
                    case .accountSelection:
                        accountSelectionContent
                    case .consentOTP:
                        consentOTPContent
                    }
                }

                if showToast {
                    VStack {
                        toastView
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .background(Color.moneBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        MoneTactileFeedback.performGentleButtonTap {
                            if isDismissProtected {
                                showLeaveAlert = true
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .foregroundStyle(Color.monePrimary)
                }
            }
            .interactiveDismissDisabled(isDismissProtected)
            .alert("Leave verification?", isPresented: $showLeaveAlert) {
                Button("Stay", role: .cancel) { }
                Button("Leave", role: .destructive) { dismiss() }
            } message: {
                Text("All progress will be lost and you will have to verify your account again.")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                SafariView(url: URL(string: "https://www.onemoney.in/tandc.html")!)
            }
            .animation(.easeInOut(duration: 0.3), value: step)
            .onChange(of: vm.step) { _, newStep in
                guard step == .phoneEntry || step == .otpEntry else { return }
                switch newStep {
                case .otpEntry:
                    step = .otpEntry
                case .verified:
                    handleOTPVerified()
                case .phoneEntry:
                    step = .phoneEntry
                }
            }
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.moneHealthy)
            Text("Phone verified")
                .font(.moneBodyMd)
                .foregroundStyle(Color.monePrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.moneSurfaceEl)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.moneStroke, lineWidth: 1))
    }

    // MARK: - Phone Entry

    private var phoneEntryContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text(subtitle)
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOBILE NUMBER")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    Text("\u{1F1EE}\u{1F1F3}")
                                        .font(.system(size: 22))
                                    Text("+91")
                                        .font(.moneBodyLg)
                                        .foregroundStyle(Color.monePrimary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.moneTertiary)
                                }

                                TextField("00000 00000", text: $vm.phone)
                                    .focused($isPhoneFocused)
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.monePrimary)
                                    .disabled(vm.isLoading)
                                    .onChange(of: vm.phone) { oldValue, newValue in
                                        let sanitized = String(newValue.filter(\.isNumber).prefix(10))
                                        if sanitized != newValue {
                                            vm.phone = sanitized
                                            return
                                        }

                                        let oldDigits = oldValue.filter(\.isNumber)
                                        if oldDigits.count < 6 && canSendOTP {
                                            Task { await vm.sendOTP() }
                                        }
                                    }

                                if vm.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(Color.monePrimary)
                                }
                            }
                            .padding(.bottom, 14)

                            Rectangle()
                                .fill(Color.moneStrokeMid)
                                .frame(height: 1)
                        }
                    }

                    if let error = vm.error {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }

                    if showConsent {
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                MoneTactileFeedback.playSelection(isSelected: !consentAccepted)
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
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            MonePrimaryButton(title: vm.isLoading ? "Sending OTP..." : "Get OTP") {
                MoneTactileFeedback.performGentleButtonTap {
                    Task { await vm.sendOTP() }
                }
            }
            .opacity(canSendOTP ? 1 : 0.4)
            .disabled(!canSendOTP)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
        .onAppear { isPhoneFocused = true }
    }

    // MARK: - OTP Entry

    private var otpEntryContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enter\nverification code")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)

                        (Text("You'll get a 6-digit code on ")
                            .foregroundStyle(Color.moneSecondary) +
                        Text("+91 \(vm.phone)")
                            .foregroundStyle(Color.monePrimary))
                            .font(.moneBodyLg)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("VERIFICATION CODE")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        OTPField(otp: $vm.otp)
                    }

                    if let error = vm.error {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }
            .task(id: vm.timerGeneration) {
                vm.resendCountdown = 30
                while vm.resendCountdown > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    vm.resendCountdown -= 1
                }
            }
            .onChange(of: vm.otp) { oldValue, newValue in
                if newValue.count == 6 && newValue.allSatisfy(\.isNumber) && oldValue.count < 6 && !vm.isLoading {
                    Task { await vm.verifyOTP() }
                }
            }

            VStack(spacing: MoneSpacing.gutter) {
                Button {
                    Task {
                        await vm.resendOTP()
                    }
                } label: {
                    if vm.resendCountdown > 0 {
                        Text("Resend code in \(vm.resendCountdown)s")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneTertiary)
                    } else {
                        Text("Resend code")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)
                            .underline()
                    }
                }
                .disabled(vm.isLoading || vm.resendCountdown > 0)
                .buttonStyle(.plain)
                .padding(.vertical, 12)

                HStack(spacing: MoneSpacing.gutter) {
                    MoneIconButton(icon: "chevron.left") {
                        MoneTactileFeedback.performGentleButtonTap {
                            vm.step = .phoneEntry
                            vm.otp = ""
                            vm.error = nil
                        }
                    }
                    MonePrimaryButton(title: vm.isLoading ? "Verifying..." : "Verify") {
                        MoneTactileFeedback.performGentleButtonTap {
                            Task { await vm.verifyOTP() }
                        }
                    }
                    .opacity(vm.isLoading || !vm.isOTPValid ? 0.4 : 1)
                    .disabled(vm.isLoading || !vm.isOTPValid)
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
    }

    // MARK: - PAN Entry

    private var panEntryContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Verify your PAN")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("Enter the PAN linked to +91 \(vm.phone)")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 24)

                    MoneField(label: "PAN NUMBER") {
                        HStack(spacing: 12) {
                            TextField("", text: $pan, prompt: .monePlaceholder("ABCDE1234F"))
                                .focused($isPanFocused)
                                .keyboardType(.asciiCapable)
                                .textInputAutocapitalization(.characters)
                                .moneFieldStyle()
                                .disabled(panLoading)
                                .onChange(of: pan) { _, newValue in
                                    pan = String(newValue.uppercased().prefix(10))
                                    panError = nil
                                }

                            if panLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Color.monePrimary)
                            }
                        }
                    }

                    if let error = panError {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            MonePrimaryButton(title: panLoading ? "Verifying..." : "Continue") {
                MoneTactileFeedback.performGentleButtonTap {
                    Task { await verifyPAN() }
                }
            }
            .opacity(canVerifyPAN ? 1 : 0.4)
            .disabled(!canVerifyPAN)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
        .onAppear { isPanFocused = true }
    }

    private var isPANFormatValid: Bool {
        let pattern = /^[A-Z]{5}[0-9]{4}[A-Z]$/
        return pan.wholeMatch(of: pattern) != nil
    }

    private var canVerifyPAN: Bool {
        !panLoading && isPANFormatValid
    }

    private var expectedPAN: String? {
        let mapping: [String: String] = [
            "8828290489": "ETTPK9327L",
            "7304893952": "ETTRK9905L"
        ]
        return mapping[vm.phone]
    }

    private func verifyPAN() async {
        panLoading = true
        try? await Task.sleep(for: .milliseconds(1500))
        if pan == expectedPAN {
            panError = nil
            panLoading = false
            appVM.enteredPAN = pan
            step = .accountSelection
        } else {
            panError = "We could not verify your PAN with the number +91 \(vm.phone)"
            panLoading = false
        }
    }

    // MARK: - Account Selection

    private var selectedCount: Int {
        accounts.filter(\.isSelected).count
    }

    private var accountSelectionContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your accounts")
                                .font(.moneDisplayMd)
                                .foregroundStyle(Color.monePrimary)
                            Text("\(selectedCount) of \(accounts.count) accounts selected")
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.moneSecondary)
                        }

                        Spacer()

                        Button(isEditingAccounts ? "Done" : "Edit") {
                            isEditingAccounts.toggle()
                        }
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneActionFill)
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 20) {
                        ForEach(groupedAccounts, id: \.institution) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    CompanyLogoView(
                                        query: group.institution,
                                        fallbackSystemName: group.icon,
                                        padding: 2
                                    )
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    Text(group.institution.uppercased())
                                        .font(.moneLabelCaps)
                                        .tracking(1.5)
                                        .foregroundStyle(Color.moneTertiary)
                                }

                                ForEach(group.accounts) { account in
                                    accountRow(account)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            MonePrimaryButton(title: "Continue") {
                MoneTactileFeedback.performGentleButtonTap {
                    vm.otp = ""
                    vm.error = nil
                    consentOTP = ""
                    consentOTPError = nil
                    Task { await vm.sendOTP() }
                    step = .consentOTP
                    consentOTPTimerGeneration = UUID()
                }
            }
            .opacity(selectedCount > 0 ? 1 : 0.4)
            .disabled(selectedCount == 0)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
        .onAppear {
            if accounts.isEmpty {
                accounts = FIAccountData.accounts(for: vm.phone)
            }
        }
    }

    private var groupedAccounts: [(institution: String, icon: String, accounts: [FIAccount])] {
        var seen: [String] = []
        var groups: [(institution: String, icon: String, accounts: [FIAccount])] = []
        for account in accounts {
            if let idx = seen.firstIndex(of: account.institution) {
                groups[idx].accounts.append(account)
            } else {
                seen.append(account.institution)
                groups.append((institution: account.institution, icon: account.icon, accounts: [account]))
            }
        }
        return groups
    }

    private func accountRow(_ account: FIAccount) -> some View {
        HStack(spacing: 12) {
            Button {
                guard isEditingAccounts else { return }
                if account.isSelected && selectedCount <= 1 { return }
                if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                    MoneTactileFeedback.playSelection(isSelected: !accounts[idx].isSelected)
                    accounts[idx].isSelected.toggle()
                }
            } label: {
                Image(systemName: account.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        !isEditingAccounts ? Color.moneSecondary :
                            account.isSelected ? Color.moneActionFill : Color.moneStrokeMid
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEditingAccounts)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountType)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.monePrimary)
                Text(account.maskedNumber)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneTertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Consent OTP

    private var consentOTPContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Authorise data access")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)

                        (Text("We sent a 6-digit code to ")
                            .foregroundStyle(Color.moneSecondary) +
                        Text("+91 \(vm.phone)")
                            .foregroundStyle(Color.monePrimary))
                            .font(.moneBodyLg)
                    }
                    .padding(.top, 24)

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.moneActionFill)

                        Text("I allow moné to access my profile, summary, and transactions details from 18 May 2025 to 18 May 2026. Data will be directly offloaded to your device. The validity of this mediator consent is up to 18 Jun 2026.")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("VERIFICATION CODE")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        OTPField(otp: $consentOTP)
                    }

                    if let error = consentOTPError {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }
            .task(id: consentOTPTimerGeneration) {
                consentOTPResendCountdown = 30
                while consentOTPResendCountdown > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    consentOTPResendCountdown -= 1
                }
            }
            .onChange(of: consentOTP) { oldValue, newValue in
                if newValue.count == 6 && newValue.allSatisfy(\.isNumber) && oldValue.count < 6 && !consentOTPLoading {
                    Task { await verifyConsentOTP() }
                }
            }

            VStack(spacing: MoneSpacing.gutter) {
                Button {
                    Task { await vm.resendOTP() }
                    consentOTPTimerGeneration = UUID()
                } label: {
                    if consentOTPResendCountdown > 0 {
                        Text("Resend code in \(consentOTPResendCountdown)s")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneTertiary)
                    } else {
                        Text("Resend code")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)
                            .underline()
                    }
                }
                .disabled(consentOTPLoading || consentOTPResendCountdown > 0)
                .buttonStyle(.plain)
                .padding(.vertical, 12)

                HStack(spacing: MoneSpacing.gutter) {
                    MoneIconButton(icon: "chevron.left") {
                        MoneTactileFeedback.performGentleButtonTap {
                            consentOTP = ""
                            consentOTPError = nil
                            step = .accountSelection
                        }
                    }
                    MonePrimaryButton(title: consentOTPLoading ? "Verifying..." : "Authorise") {
                        MoneTactileFeedback.performGentleButtonTap {
                            Task { await verifyConsentOTP() }
                        }
                    }
                    .opacity(consentOTPLoading || consentOTP.count < 6 ? 0.4 : 1)
                    .disabled(consentOTPLoading || consentOTP.count < 6)
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
    }

    private func verifyConsentOTP() async {
        let code = consentOTP
        guard code.count == 6, code.allSatisfy(\.isNumber) else { return }
        consentOTPLoading = true
        consentOTPError = nil

        do {
            try await vm.otpProvider.verifyOTP(phone: "+91\(vm.phone.filter(\.isNumber))", token: code)
            consentOTPLoading = false
            appVM.aaConsentId = "mock_consent_\(UUID().uuidString)"
            onVerified(vm.phone)
            dismiss()
        } catch {
            consentOTPError = "Invalid or expired code. Please try again."
            consentOTP = ""
            consentOTPLoading = false
        }
    }

    // MARK: - OTP Verified Handler

    private func handleOTPVerified() {
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast = false }
            step = .panEntry
        }
    }

    private var isDismissProtected: Bool {
        step == .panEntry || step == .accountSelection || step == .consentOTP
    }

    private var canSendOTP: Bool {
        !vm.isLoading && vm.isPhoneValid && (!showConsent || consentAccepted)
    }

}

// MARK: - FI Account Model

struct FIAccount: Identifiable {
    let id = UUID()
    let institution: String
    let maskedNumber: String
    let accountType: String
    let icon: String
    var isSelected: Bool = true
}

enum FIAccountData {
    static func accounts(for phone: String) -> [FIAccount] {
        switch phone {
        case "8828290489":
            return [
                FIAccount(institution: "HDFC Bank", maskedNumber: "XXXXXXXX1234", accountType: "Savings Account", icon: "building.columns"),
                FIAccount(institution: "HDFC Bank", maskedNumber: "RDXXXX3456", accountType: "Recurring Deposit", icon: "building.columns"),
                FIAccount(institution: "HDFC Bank", maskedNumber: "TDXXXX4567", accountType: "Term Deposit", icon: "building.columns"),
                FIAccount(institution: "HDFC Bank", maskedNumber: "XXXXXXXX9821", accountType: "Credit Card", icon: "creditcard"),
                FIAccount(institution: "Bajaj Finance", maskedNumber: "LANXXXX6408", accountType: "Consumer Durable Loan", icon: "indianrupeesign.circle"),
                FIAccount(institution: "HDFC Mutual Fund", maskedNumber: "MFXXXX2345", accountType: "Mutual Fund (SIP)", icon: "chart.line.uptrend.xyaxis"),
                FIAccount(institution: "Axis Mutual Fund", maskedNumber: "MFXXXX8726", accountType: "Mutual Fund (SIP)", icon: "chart.line.uptrend.xyaxis"),
            ]
        case "7304893952":
            return [
                FIAccount(institution: "HDFC Bank", maskedNumber: "XXXXXXXX7788", accountType: "Savings Account", icon: "building.columns"),
                FIAccount(institution: "HDFC Bank", maskedNumber: "RDXXXX7788", accountType: "Recurring Deposit", icon: "building.columns"),
                FIAccount(institution: "HDFC Bank", maskedNumber: "TDXXXX7788", accountType: "Term Deposit", icon: "building.columns"),
                FIAccount(institution: "HDFC Bank", maskedNumber: "XXXXXXXX4419", accountType: "Credit Card", icon: "creditcard"),
                FIAccount(institution: "ICICI Bank", maskedNumber: "XXXXXXXX6204", accountType: "Savings Account", icon: "building.columns"),
                FIAccount(institution: "HDFC Credila", maskedNumber: "EDUXXXX2208", accountType: "Education Loan", icon: "indianrupeesign.circle"),
                FIAccount(institution: "ICICI Prudential MF", maskedNumber: "MFXXXX7788", accountType: "Mutual Fund (SIP)", icon: "chart.line.uptrend.xyaxis"),
                FIAccount(institution: "NPS (Protean)", maskedNumber: "PRANXXXX6142", accountType: "NPS Tier I", icon: "lock.shield"),
                FIAccount(institution: "HDFC ERGO", maskedNumber: "HEXXXX4301", accountType: "Health Insurance", icon: "heart.text.square"),
                FIAccount(institution: "Axis Max Life", maskedNumber: "LIXXXX5912", accountType: "Term Life Insurance", icon: "shield.checkered"),
                FIAccount(institution: "Care Health", maskedNumber: "CHXXXX2479", accountType: "Health Insurance", icon: "heart.text.square"),
                FIAccount(institution: "Insurance Repository", maskedNumber: "INXXXX7788", accountType: "e-Insurance Account", icon: "doc.text"),
            ]
        default:
            return []
        }
    }

    static func grouped(for phone: String) -> [(institution: String, icon: String, accounts: [FIAccount])] {
        let all = accounts(for: phone)
        var seen: [String] = []
        var groups: [(institution: String, icon: String, accounts: [FIAccount])] = []
        for account in all {
            if let idx = seen.firstIndex(of: account.institution) {
                groups[idx].accounts.append(account)
            } else {
                seen.append(account.institution)
                groups.append((institution: account.institution, icon: account.icon, accounts: [account]))
            }
        }
        return groups
    }
}
