import SwiftUI
import Supabase

struct PhoneVerificationView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var vm = PhoneVerificationVM()

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

            switch vm.step {
            case .phoneEntry:
                phoneEntryContent
            case .otpEntry:
                otpEntryContent
            case .verified:
                verifiedContent
            }
        }
        .background(Color.moneBackground.ignoresSafeArea())
    }

    // MARK: - Phone Entry

    private var phoneEntryContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Verify your\nphone number")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("We'll verify your number before the demo Account Aggregator-style fetch starts.")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOBILE NUMBER")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        HStack(spacing: 8) {
                            Text("+91")
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.moneTertiary)

                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    TextField("", text: $vm.phone, prompt: Text("10-digit mobile").foregroundColor(.moneTertiary))
                                        .keyboardType(.numberPad)
                                        .font(.moneBodyLg)
                                        .foregroundStyle(Color.monePrimary)
                                        .tint(Color.monePrimary)
                                        .disabled(vm.isLoading)
                                        .onChange(of: vm.phone) { _, newValue in
                                            vm.phone = String(newValue.filter(\.isNumber).prefix(10))
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

                        if vm.phone.count == 10 {
                            Text(demoHint(for: vm.phone))
                                .font(.moneBodySm)
                                .foregroundStyle(demoHintColor(for: vm.phone))
                        }
                    }

                    if let error = vm.error {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            VStack(spacing: MoneSpacing.gutter) {
                MonePrimaryButton(title: vm.isLoading ? "Sending OTP..." : "Get OTP") {
                    Task { await vm.sendOTP() }
                }
                .opacity(vm.isLoading || !vm.isPhoneValid ? 0.4 : 1)
                .disabled(vm.isLoading || !vm.isPhoneValid)

                Button { appVM.goBack() } label: {
                    Text("Go back")
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
    }

    // MARK: - OTP Entry

    private var otpEntryContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enter the code")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("We sent a 6-digit code to +91 \(vm.phone)")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("OTP CODE")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        VStack(spacing: 0) {
                            TextField("", text: $vm.otp, prompt: Text("6-digit code").foregroundColor(.moneTertiary))
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .font(.moneAmtMd)
                                .foregroundStyle(Color.monePrimary)
                                .tint(Color.monePrimary)
                                .padding(.bottom, 14)
                                .onChange(of: vm.otp) { _, newValue in
                                    vm.otp = String(newValue.filter(\.isNumber).prefix(6))
                                    if vm.otp.count == 6 {
                                        Task { await vm.verifyOTP() }
                                    }
                                }

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

                    HStack {
                        if vm.resendCountdown > 0 {
                            Text("Resend in \(vm.resendCountdown)s")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneTertiary)
                        } else {
                            Button("Resend code") {
                                Task { await vm.resendOTP() }
                            }
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                            .disabled(vm.isLoading)
                        }
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            VStack(spacing: MoneSpacing.gutter) {
                MonePrimaryButton(title: vm.isLoading ? "Verifying..." : "Verify") {
                    Task { await vm.verifyOTP() }
                }
                .opacity(vm.isLoading || !vm.isOTPValid ? 0.4 : 1)
                .disabled(vm.isLoading || !vm.isOTPValid)

                Button {
                    vm.step = .phoneEntry
                    vm.otp = ""
                    vm.error = nil
                } label: {
                    Text("Change number")
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
        .task(id: vm.timerGeneration) {
            vm.resendCountdown = 30
            while vm.resendCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                vm.resendCountdown -= 1
            }
        }
    }

    // MARK: - Verified

    private var verifiedContent: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.moneHealthy)

                Text("Phone verified")
                    .font(.moneHL)
                    .foregroundStyle(Color.monePrimary)

                if let name = DummyAAProvider.personaName(for: vm.phone) {
                    Text("Preparing the demo connection for \(name).")
                        .font(.moneBodyLg)
                        .foregroundStyle(Color.moneSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .onAppear {
            appVM.verifiedPhone = vm.phone
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                appVM.advance()
            }
        }
    }

    private func demoHint(for phone: String) -> String {
        switch DummyAAProvider.demoState(for: phone) {
        case .aarav:
            return "Aarav demo data will load after verification."
        case .priyaNotWired:
            return "Priya demo data is not wired yet; you'll see a retry state after verification."
        case .unsupported:
            return "Unsupported demo number. Try 8828290489 for Aarav."
        }
    }

    private func demoHintColor(for phone: String) -> Color {
        DummyAAProvider.demoState(for: phone) == .aarav ? .moneHealthy : .moneWatch
    }
}

// MARK: - Phone Verification VM

protocol PhoneOTPProviding {
    func sendOTP(phone: String) async throws
    func verifyOTP(phone: String, token: String) async throws
}

struct SupabasePhoneOTPProvider: PhoneOTPProviding {
    func sendOTP(phone: String) async throws {
        try await supabase.auth.signInWithOTP(phone: phone)
    }

    func verifyOTP(phone: String, token: String) async throws {
        try await supabase.auth.verifyOTP(phone: phone, token: token, type: .sms)
    }
}

struct DevPhoneOTPProvider: PhoneOTPProviding {
    func sendOTP(phone: String) async throws {}

    func verifyOTP(phone: String, token: String) async throws {
        guard token == "000000" else {
            throw PhoneOTPError.invalidCode
        }
    }
}

enum PhoneOTPError: Error {
    case invalidCode
}

@MainActor @Observable
final class PhoneVerificationVM {
    enum Step { case phoneEntry, otpEntry, verified }

    var step: Step = .phoneEntry
    var phone = ""
    var otp = ""
    var isLoading = false
    var error: String?
    var resendCountdown: Int = 30
    var timerGeneration = UUID()
    private(set) var otpProvider: PhoneOTPProviding

    // DEMO MODE: flip to false (or restore env-var check) to use real SMS OTP
    private static let demoMode = true

    init() {
        if Self.demoMode || ProcessInfo.processInfo.environment["MONE_DEV_OTP_ENABLED"] == "1" {
            otpProvider = DevPhoneOTPProvider()
        } else {
            otpProvider = SupabasePhoneOTPProvider()
        }
    }

    var isPhoneValid: Bool {
        phone.filter(\.isNumber).count == 10
    }

    var isOTPValid: Bool {
        otp.count == 6 && otp.allSatisfy(\.isNumber)
    }

    private var e164Phone: String {
        "+91\(phone.filter(\.isNumber))"
    }

    func sendOTP() async {
        guard isPhoneValid else { return }
        isLoading = true
        error = nil

        do {
            try await otpProvider.sendOTP(phone: e164Phone)
            step = .otpEntry
            timerGeneration = UUID()
        } catch {
            self.error = "Could not send OTP. Please check the number and try again."
        }

        isLoading = false
    }

    func resendOTP() async {
        isLoading = true
        error = nil

        do {
            try await otpProvider.sendOTP(phone: e164Phone)
            timerGeneration = UUID()
        } catch {
            self.error = "Could not resend OTP. Please try again."
        }

        isLoading = false
    }

    func verifyOTP() async {
        guard isOTPValid else { return }
        isLoading = true
        error = nil

        do {
            try await otpProvider.verifyOTP(phone: e164Phone, token: otp)
            step = .verified
        } catch {
            self.error = "Invalid or expired code. Please try again."
            otp = ""
        }

        isLoading = false
    }
}
