import SwiftUI
import Supabase

// MARK: - Sign-Up Sheet

struct SignUpSheet: View {
    enum Step {
        case prompt
        case phoneEntry
        case otp(phone: String)
        case nameEntry
        case restoring
    }

    let aaPhone: String           // e.g. "8828290489" from AppViewModel.verifiedPhone
    var onDismissed: () -> Void   // called when user dismisses from prompt
    var onComplete: () -> Void    // called when sign-up or restore is done

    @Environment(SessionViewModel.self) private var sessionVM
    @State private var step: Step = .prompt
    @State private var authVM = AuthViewModel()
    @State private var name = ""
    @State private var nameError: String?
    @State private var isSavingName = false
    @FocusState private var isNameFocused: Bool

    // Formatted E.164 number from the 10-digit AA phone
    private var e164AAPhone: String { "+91\(aaPhone)" }

    // Last 4 digits for display
    private var maskedPhone: String {
        let digits = aaPhone.filter(\.isNumber)
        guard digits.count >= 4 else { return aaPhone }
        return "+91 ●●●●●● \(digits.suffix(4))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.moneBackground.ignoresSafeArea()

                switch step {
                case .prompt:
                    promptContent
                case .phoneEntry:
                    PhoneEntryScreen(
                        vm: authVM,
                        onBack: { step = .prompt },
                        title: "Sign up securely",
                        subtitle: "Your data stays encrypted. Only you can read it — on device and in the cloud."
                    )
                case .otp(let phone):
                    OTPScreen(vm: authVM, destination: phone)
                case .nameEntry:
                    nameEntryContent
                case .restoring:
                    restoringContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .prompt = step {
                        Button("Skip") { onDismissed() }
                            .foregroundStyle(Color.moneTertiary)
                    }
                }
            }
            .interactiveDismissDisabled({
                if case .nameEntry = step { return true }
                if case .prompt = step { return false }
                return false
            }())
            .animation(.easeInOut(duration: 0.25), value: authVM.screen)
            .onChange(of: authVM.screen) { _, screen in
                switch screen {
                case .phoneOTP(let phone):
                    step = .otp(phone: phone)
                case .signedIn:
                    Task { await handleSignedIn() }
                default:
                    break
                }
            }
        }
    }

    // MARK: - Prompt

    private var promptContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sign up to securely save your financial profile")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)

                        Text("Your data remains with you, locally as well as on the cloud. Your data remains encrypted on the cloud and no one except you can read it.")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            VStack(spacing: MoneSpacing.gutter) {
                Button {
                    step = .phoneEntry
                } label: {
                    Text("Sign up with a different number or email id")
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneSecondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)

                MonePrimaryButton(title: "Sign up using \(maskedPhone)") {
                    Task { await sendOTPToAAPhone() }
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
            .background(Color.moneBackground)
        }
    }

    // MARK: - Name Entry

    private var nameEntryContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What should we call you?")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("This is how moné will address you.")
                            .font(.moneBodyLg)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 28)

                    MoneField(label: "YOUR NAME") {
                        TextField("", text: $name, prompt: .monePlaceholder("Full name"))
                            .focused($isNameFocused)
                            .textContentType(.name)
                            .moneFieldStyle()
                    }

                    if let error = nameError {
                        Text(error)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }
                }
                .padding(.horizontal, MoneSpacing.page)
            }

            MonePrimaryButton(title: isSavingName ? "Saving..." : "Continue") {
                Task { await saveName() }
            }
            .opacity(isSavingName || name.trimmingCharacters(in: .whitespaces).count < 2 ? 0.4 : 1)
            .disabled(isSavingName || name.trimmingCharacters(in: .whitespaces).count < 2)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, MoneSpacing.gutter)
            .padding(.bottom, MoneSpacing.gutter)
        }
        .onAppear { isNameFocused = true }
    }

    // MARK: - Restoring

    private var restoringContent: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .tint(Color.monePrimary)
            VStack(spacing: 8) {
                Text("Your encrypted financial data is already with us.")
                    .font(.moneBodyLg)
                    .foregroundStyle(Color.monePrimary)
                    .multilineTextAlignment(.center)
                Text("Restoring your profile…")
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, MoneSpacing.page)
        .task {
            try? await Task.sleep(for: .seconds(2))
            onComplete()
        }
    }

    // MARK: - Actions

    private func sendOTPToAAPhone() async {
        // Pre-fill AuthViewModel phone with the AA number and trigger OTP send
        authVM.phone = aaPhone
        await authVM.sendPhoneOTP()
        // screen transition handled via onChange(of: authVM.screen)
    }

    private func handleSignedIn() async {
        guard let userId = supabase.auth.currentSession?.user.id else { return }
        do {
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            if let profile = profiles.first,
               let fullName = profile.fullName,
               !fullName.trimmingCharacters(in: .whitespaces).isEmpty {
                // Existing user — update session state and show restoring UI
                sessionVM.profile = profile
                step = .restoring
            } else {
                step = .nameEntry
            }
        } catch {
            step = .nameEntry
        }
    }

    private func saveName() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            nameError = "Name must be at least 2 characters."
            return
        }
        isSavingName = true
        nameError = nil
        do {
            try await sessionVM.completeSignUp(name: trimmed)
            onComplete()
        } catch {
            nameError = "Failed to save. Please try again."
        }
        isSavingName = false
    }
}
