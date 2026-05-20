import SwiftUI
import Supabase

// MARK: - Auth Screen State

enum AuthScreen: Equatable {
    case emailEntry
    case phoneEntry
    case emailOTP(email: String)
    case phoneOTP(phone: String)
    case signedIn(identifier: String)
}

enum AuthIntent {
    case login
    case signup
}

// MARK: - Auth View Model

@MainActor @Observable
final class AuthViewModel {
    var screen: AuthScreen = .phoneEntry
    var email = ""
    var phone = ""
    var otp = ""
    var isLoading = false
    var errorMessage: String?
    var resendMessage: String?
    
    var authIntent: AuthIntent = .login

    private let registrationService = AuthRegistrationService()

    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.contains("@") && trimmed.contains(".")
    }

    private var phoneDigits: String {
        phone.filter(\.isNumber)
    }

    var isPhoneValid: Bool {
        phoneDigits.count == 10
    }

    private var e164Phone: String {
        "+91\(phoneDigits)"
    }

    var isOTPValid: Bool {
        otp.count == 6 && otp.allSatisfy(\.isNumber)
    }

    var isPhoneOTPScreen: Bool {
        if case .phoneOTP = screen { return true }
        return false
    }

    var existingProfileName: String?

    func checkExistingSession() {
        guard let session = supabase.auth.currentSession else { return }
        if let email = session.user.email, !email.isEmpty {
            screen = .signedIn(identifier: email)
        } else if let phone = session.user.phone, !phone.isEmpty {
            screen = .signedIn(identifier: phone)
        }
        Task { await fetchProfileName() }
    }

    func fetchProfileName() async {
        guard let userId = supabase.auth.currentSession?.user.id else { return }
        do {
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            existingProfileName = profiles.first?.fullName
        } catch {}
    }

    // MARK: Email OTP

    func sendEmailOTP() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        let trimmedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        do {
            let status = try await registrationService.checkEmail(trimmedEmail)

            switch authIntent {
            case .login:
                guard status.registered else {
                    errorMessage = "No account found for this email. Please sign up first."
                    isLoading = false
                    return
                }

            case .signup:
                guard !status.registered else {
                    errorMessage = "This email already has an account. Please log in instead."
                    isLoading = false
                    return
                }
            }

            try await supabase.auth.signInWithOTP(email: trimmedEmail)
            screen = .emailOTP(email: trimmedEmail)
            otp = ""
        } catch {
            errorMessage = friendlyError(error)
        }

        isLoading = false
    }

    func verifyEmailOTP() async {
        guard isOTPValid else {
            errorMessage = "Enter the 6-digit code from your email."
            return
        }

        guard case .emailOTP(let sentEmail) = screen else { return }

        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.verifyOTP(
                email: sentEmail,
                token: otp,
                type: .email
            )
            screen = .signedIn(identifier: session.user.email ?? sentEmail)
            Task { await fetchProfileName() }
        } catch {
            errorMessage = "Invalid or expired code. Please try again."
        }

        isLoading = false
    }

    // MARK: Phone OTP

    func sendPhoneOTP() async {
        guard isPhoneValid else {
            errorMessage = "Enter a valid 10-digit mobile number."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let status = try await registrationService.checkPhone(phoneDigits)

            switch authIntent {
            case .login:
                guard status.registered else {
                    errorMessage = "No account found for this number. Please sign up first."
                    isLoading = false
                    return
                }

            case .signup:
                guard !status.registered else {
                    errorMessage = "This number already has an account. Please log in instead."
                    isLoading = false
                    return
                }
            }

            let formatted = e164Phone
            print("[Auth] Sending phone OTP to +91****\(phoneDigits.suffix(4))")

            try await supabase.auth.signInWithOTP(phone: formatted)

            print("[Auth] signInWithOTP(phone:) returned successfully")
            screen = .phoneOTP(phone: formatted)
            otp = ""
        } catch {
            print("[Auth] sendPhoneOTP failed: \(error)")
            errorMessage = friendlyError(error)
        }

        isLoading = false
    }

    func verifyPhoneOTP() async {
        guard isOTPValid else {
            errorMessage = "Enter the 6-digit code sent to your phone."
            return
        }

        guard case .phoneOTP(let sentPhone) = screen else { return }

        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.verifyOTP(
                phone: sentPhone,
                token: otp,
                type: .sms
            )
            let identifier = session.user.phone ?? sentPhone
            screen = .signedIn(identifier: identifier)
            Task { await fetchProfileName() }
        } catch {
            errorMessage = "Invalid or expired code. Please try again."
        }

        isLoading = false
    }

    // MARK: Verify (dispatches to email or phone)

    func verifyCurrentOTP() async {
        switch screen {
        case .emailOTP: await verifyEmailOTP()
        case .phoneOTP: await verifyPhoneOTP()
        default: break
        }
    }

    // MARK: Resend

    func resendOTP() async {
        isLoading = true
        errorMessage = nil
        resendMessage = nil

        do {
            switch screen {
            case .emailOTP(let sentEmail):
                try await supabase.auth.signInWithOTP(email: sentEmail)
                resendMessage = "Code resent to \(sentEmail)"
            case .phoneOTP(let sentPhone):
                try await supabase.auth.signInWithOTP(phone: sentPhone)
                resendMessage = "Code resent to your phone"
            default:
                break
            }
        } catch {
            errorMessage = friendlyError(error)
        }

        isLoading = false
    }

    // MARK: Helpers

    private static let knownEmailDomains: Set<String> = [
        "gmail.com", "yahoo.com", "yahoo.co.in", "yahoo.in",
        "outlook.com", "hotmail.com", "live.com",
        "icloud.com", "me.com", "mac.com",
        "protonmail.com", "proton.me",
        "rediffmail.com", "aol.com",
        "zoho.com", "zoho.in",
        "mail.com", "gmx.com",
        "yandex.com", "tutanota.com",
    ]

    var hasKnownEmailDomain: Bool {
        guard let atIndex = email.lastIndex(of: "@") else { return false }
        let domain = email[email.index(after: atIndex)...].trimmingCharacters(in: .whitespaces).lowercased()
        return Self.knownEmailDomains.contains(domain)
    }

    private func friendlyError(_ error: Error) -> String {
        if case AuthRegistrationError.serverError(let message) = error {
            return "Registration check failed: \(message)"
        }

        let message = error.localizedDescription.lowercased()

        if message.contains("rate") || message.contains("too many") {
            return "Too many attempts. Please wait a moment and try again."
        }

        if message.contains("not found") || message.contains("invalid") {
            return "Could not send verification code. Please check and try again."
        }

        return "Something went wrong. Please try again."
    }

    // MARK: Navigation

    func signOut() async {
        isLoading = true
        do {
            try await supabase.auth.signOut()
        } catch {}
        screen = .phoneEntry
        email = ""
        otp = ""
        phone = ""
        errorMessage = nil
        resendMessage = nil
        isLoading = false
    }

    func switchToPhone() {
        errorMessage = nil
        screen = .phoneEntry
    }

    func switchToEmail() {
        errorMessage = nil
        screen = .emailEntry
    }

    func goBack() {
        errorMessage = nil
        resendMessage = nil
        otp = ""
        switch screen {
        case .emailEntry: screen = .phoneEntry
        case .phoneEntry: break
        case .emailOTP: screen = .emailEntry
        case .phoneOTP: screen = .phoneEntry
        case .signedIn: break
        }
    }
}

// MARK: - Auth View

struct AuthView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var vm = AuthViewModel()

    var onAuthComplete: (() -> Void)?
    var showBackButton: Bool = true

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            Group {
                switch vm.screen {
                case .phoneEntry:
                    PhoneEntryScreen(vm: vm, onBack: showBackButton ? { appVM.goBack() } : nil)
                case .emailEntry:
                    EmailEntryScreen(vm: vm, onBack: { vm.goBack() })
                case .emailOTP(let email):
                    OTPScreen(vm: vm, destination: email)
                case .phoneOTP(let phone):
                    OTPScreen(vm: vm, destination: phone)
                case .signedIn(let identifier):
                    SignedInScreen(vm: vm, identifier: identifier, onContinue: {
                        if let onAuthComplete {
                            onAuthComplete()
                        } else {
                            appVM.advance()
                        }
                    })
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: vm.screen)
        .onAppear { vm.checkExistingSession() }
    }
}

// MARK: - Phone Entry Screen

struct PhoneEntryScreen: View {
    @Bindable var vm: AuthViewModel
    var onBack: (() -> Void)?
    var title: String = "Access your \nsecure vault"
    var subtitle: String = "We are sending a 6-digit code to your mobile number."
    @FocusState private var isPhoneFocused: Bool

    var body: some View {
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
                    .padding(.top, 28)

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
                                    .onChange(of: vm.phone) { oldValue, _ in
                                        let oldDigits = oldValue.filter(\.isNumber)
                                        if oldDigits.count < 6 && vm.isPhoneValid && !vm.isLoading {
                                            Task { await vm.sendPhoneOTP() }
                                        }
                                    }
                            }
                            .padding(.bottom, 14)

                            Rectangle()
                                .fill(Color.moneStrokeMid)
                                .frame(height: 1)
                        }
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }
            .contentShape(Rectangle())
            .onTapGesture { isPhoneFocused = false }

            VStack(spacing: MoneSpacing.gutter) {
                SecondaryAuthButton(title: "Use email instead") {
                    vm.switchToEmail()
                }

                HStack(spacing: MoneSpacing.gutter) {
                    
                    MonePrimaryButton(title: vm.isLoading ? "Sending..." : "Get OTP") {
                        Task { await vm.sendPhoneOTP() }
                    }
                    .opacity(vm.isLoading || !vm.isPhoneValid ? 0.4 : 1)
                    .disabled(vm.isLoading || !vm.isPhoneValid)
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
            .background(Color.moneBackground)
        }
        .onAppear { isPhoneFocused = true }
    }
}

// MARK: - Email Entry Screen

private struct EmailEntryScreen: View {
    @Bindable var vm: AuthViewModel
    var onBack: () -> Void
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Access your \nsecure vault")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("We are sending an OTP code to your email address.")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 28)

                    MoneField(label: "EMAIL ADDRESS") {
                        TextField("", text: $vm.email, prompt: .monePlaceholder("name@example.com"))
                            .focused($isEmailFocused)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .moneFieldStyle()
                            .onChange(of: vm.email) { oldValue, _ in
                                if oldValue.count < 6 && vm.isEmailValid && vm.hasKnownEmailDomain && !vm.isLoading {
                                    Task { await vm.sendEmailOTP() }
                                }
                            }
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }
            .contentShape(Rectangle())
            .onTapGesture { isEmailFocused = false }

            VStack(spacing: MoneSpacing.gutter) {
                SecondaryAuthButton(title: "Use mobile number instead") {
                    vm.switchToPhone()
                }

                HStack(spacing: MoneSpacing.gutter) {
                    
                    MonePrimaryButton(title: vm.isLoading ? "Sending..." : "Get OTP") {
                        Task { await vm.sendEmailOTP() }
                    }
                    .opacity(vm.isLoading || !vm.isEmailValid ? 0.4 : 1)
                    .disabled(vm.isLoading || !vm.isEmailValid)
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
            .background(Color.moneBackground)
        }
        .onAppear { isEmailFocused = true }
    }
}

// MARK: - OTP Screen

struct OTPScreen: View {
    @Bindable var vm: AuthViewModel
    let destination: String
    @State private var resendCountdown: Int = 30
    @State private var timerGeneration: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enter\nverification code")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)

                        (Text("We sent a 6-digit code to ")
                            .foregroundStyle(Color.moneSecondary) +
                        Text(destination)
                            .foregroundStyle(Color.monePrimary))
                            .font(.moneBodyLg)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("VERIFICATION CODE")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        OTPField(otp: $vm.otp)
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }

                    if let msg = vm.resendMessage {
                        Text(msg)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneHealthy)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            VStack(spacing: MoneSpacing.gutter) {
                Button {
                    Task {
                        await vm.resendOTP()
                        timerGeneration += 1
                    }
                } label: {
                    if resendCountdown > 0 {
                        Text("Resend code in \(resendCountdown)s")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneTertiary)
                    } else {
                        Text("Resend code")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)
                            .underline()
                    }
                }
                .disabled(vm.isLoading || resendCountdown > 0)
                .buttonStyle(.plain)
                .padding(.vertical, 12)

                HStack(spacing: MoneSpacing.gutter) {
                    MoneIconButton(icon: "chevron.left") {
                        vm.goBack()
                    }
                    MonePrimaryButton(title: vm.isLoading ? "Verifying..." : "Verify") {
                        Task { await vm.verifyCurrentOTP() }
                    }
                    .opacity(vm.isLoading || !vm.isOTPValid ? 0.4 : 1)
                    .disabled(vm.isLoading || !vm.isOTPValid)
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
            .background(Color.moneBackground)
        }
        .task(id: timerGeneration) {
            resendCountdown = 30
            while resendCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCountdown -= 1
            }
        }
        .onChange(of: vm.otp) { oldValue, newValue in
            if newValue.count == 6 && newValue.allSatisfy(\.isNumber) && oldValue.count < 6 && !vm.isLoading {
                Task { await vm.verifyCurrentOTP() }
            }
        }
    }
}

// MARK: - OTP Field

struct OTPField: View {
    @Binding var otp: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .center) {
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .onChange(of: otp) { _, newValue in
                    otp = String(newValue.filter(\.isNumber).prefix(6))
                }

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    OTPDigitBox(
                        digit: digitAt(index),
                        isActive: index == otp.count && isFocused
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear { isFocused = true }
    }

    private func digitAt(_ index: Int) -> String {
        guard index < otp.count else { return "" }
        return String(otp[otp.index(otp.startIndex, offsetBy: index)])
    }
}

struct OTPDigitBox: View {
    let digit: String
    var isActive: Bool = false

    var body: some View {
        Text(digit)
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.monePrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MoneRadius.md)
                    .strokeBorder(
                        isActive ? Color.moneActionFill : Color.moneStrokeMid,
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
    }
}

// MARK: - Secondary Auth Button

private struct SecondaryAuthButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.moneSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    Capsule().strokeBorder(Color.moneStrokeMid, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Signed In Screen

private struct SignedInScreen: View {
    var vm: AuthViewModel
    let identifier: String
    var onContinue: () -> Void

    @State private var didContinue = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    Task { await vm.signOut() }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.moneTertiary)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.moneHealthy.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.moneHealthy)
                }

                if let name = vm.existingProfileName, !name.isEmpty {
                    Text("Welcome back,\n\(name.components(separatedBy: " ").first ?? name).")
                        .font(.system(size: 36, weight: .heavy, design: .serif))
                        .foregroundStyle(Color.monePrimary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("You\u{2019}re in.")
                        .font(.system(size: 36, weight: .heavy, design: .serif))
                        .foregroundStyle(Color.monePrimary)
                }

                Text(identifier)
                    .font(.moneBodyLg)
                    .foregroundStyle(Color.moneSecondary)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            MonePrimaryButton(title: "Continue to mon\u{00E9}") {
                guard !didContinue else { return }
                didContinue = true
                onContinue()
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.bottom, MoneSpacing.gutter)
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environment(AppViewModel())
}
