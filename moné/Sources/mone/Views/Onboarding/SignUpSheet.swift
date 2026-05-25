import SwiftUI
import Supabase
import SwiftData

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
    @Environment(\.modelContext) private var modelContext
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
                    if case .emailEntry = authVM.screen {
                        EmailEntryScreen(vm: authVM, onBack: { authVM.switchToPhone() })
                    } else {
                        PhoneEntryScreen(
                            vm: authVM,
                            onBack: { step = .prompt },
                            title: "Sign up securely",
                            subtitle: "Your data stays encrypted. Only you can read it — on device and in the cloud."
                        )
                    }
                case .otp(let phone):
                    OTPScreen(vm: authVM, destination: phone, title: "Enter verification\ncode")
                case .nameEntry:
                    nameEntryContent
                case .restoring:
                    restoringContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .prompt = step {
                        Button("Skip") {
                            MoneTactileFeedback.performGentleButtonTap {
                                onDismissed()
                            }
                        }
                        .foregroundStyle(Color.monePrimary)
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
                case .emailOTP(let email):
                    step = .otp(phone: email)
                case .signedIn:
                    Task { await handleSignedIn() }
                default:
                    break
                }
            }
            
            .onAppear {
                authVM.authIntent = .signup

                if supabase.auth.currentSession != nil {
                    Task {
                        do { try await supabase.auth.signOut(scope: .local) } catch {}
                    }
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
                    MoneTactileFeedback.performGentleButtonTap {
                        step = .phoneEntry
                    }
                } label: {
                    Text("Use a different number or email id")
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneSecondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)

                MonePrimaryButton(title: "Sign up using \(maskedPhone)") {
                    MoneTactileFeedback.performGentleButtonTap {
                        Task { await sendOTPToAAPhone() }
                    }
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
                MoneTactileFeedback.performGentleButtonTap {
                    Task { await saveName() }
                }
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
                // This is signup flow. Existing users should not be signed up again.
                sessionVM.profile = nil
                authVM.errorMessage = "This account already exists. Please log in instead."
                do { try await supabase.auth.signOut(scope: .local) } catch {}
                step = .prompt
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
            try await FinancialDataCloudService()
                .backupLatestLocalData(modelContext: modelContext)

            try await sessionVM.completeSignUp(name: trimmed)
            onComplete()
        } catch FinancialDataCloudError.noLocalFinancialData {
            nameError = "We could not find financial data on this device. Please complete Account Aggregator setup again."
        } catch {
            nameError = "Failed to save your financial profile. Please try again."
        }
        isSavingName = false
    }
}
