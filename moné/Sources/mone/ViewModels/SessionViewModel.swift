import SwiftUI
import Supabase

@Observable @MainActor
final class SessionViewModel {
    enum Route: Equatable {
        case loading
        case onboarding
        case auth
        case nameOnboarding
        case dashboard
    }

    var route: Route = .loading
    var profile: Profile?
    var isLoading = false
    var isDeletingAccount = false
    var error: String?
    var isReturningUser = false
    var nextOnboardingStep: AppViewModel.OnboardingStep = .agendaEducation
    var shouldForceWelcomeOnboarding = false
    var onboardingResetToken = UUID()

    var displayName: String {
        guard let full = profile?.fullName, !full.isEmpty else { return "there" }
        return full.components(separatedBy: " ").first ?? full
    }
    
    var isSignedIn: Bool {
        supabase.auth.currentSession != nil
    }

    private let recentlyDeletedUserIDsKey = "mone.recentlyDeletedUserIDs"
    private let recentlyDeletedIdentifiersKey = "mone.recentlyDeletedIdentifiers"

    private var recentlyDeletedUserIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: recentlyDeletedUserIDsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: recentlyDeletedUserIDsKey)
        }
    }

    private var recentlyDeletedIdentifiers: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: recentlyDeletedIdentifiersKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: recentlyDeletedIdentifiersKey)
        }
    }
    
    private func normalizedCurrentPhone() -> String? {
        guard let phone = supabase.auth.currentSession?.user.phone else {
            return nil
        }

        let digits = phone.filter(\.isNumber)
        guard digits.count >= 10 else {
            return nil
        }

        return String(digits.suffix(10))
    }
    
    private func normalizedCurrentEmail() -> String? {
        supabase.auth.currentSession?.user.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func initialize() async {
        route = .loading
        shouldForceWelcomeOnboarding = false
        if supabase.auth.currentSession != nil {
            await handleAuthSuccess()
        } else {
            nextOnboardingStep = .agendaEducation
            route = .onboarding
        }
    }

    func handleAuthSuccess() async {
        guard let session = supabase.auth.currentSession else {
            route = .auth
            return
        }
        shouldForceWelcomeOnboarding = false
        isLoading = true
        error = nil

        do {
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: session.user.id.uuidString)
                .execute()
                .value

            if let p = profiles.first {
                profile = p

                let hasName = !(p.fullName ?? "")
                    .trimmingCharacters(in: .whitespaces)
                    .isEmpty
                let userId = session.user.id.uuidString
                let matchesRecentlyDeletedAccount = recentlyDeletedUserIDs.contains(userId)
                    || currentSessionIdentifiers(session).contains { recentlyDeletedIdentifiers.contains($0) }

                if matchesRecentlyDeletedAccount {
                    await resetStaleProfileAfterDeletion(userId: session.user.id)
                    route = .nameOnboarding
                } else if !hasName {
                    route = .nameOnboarding
                } else if p.onboardingCompleted == true {
                    isReturningUser = true
                    route = .dashboard
                } else {
                    isReturningUser = false
                    nextOnboardingStep = onboardingStep(from: p.onboardingStep)
                    onboardingResetToken = UUID()
                    route = .onboarding
                }
            } else {
                profile = nil
                error = "We found your login session, but could not find your Moné profile. Please sign up again or contact support."
                do { try await supabase.auth.signOut(scope: .local) } catch {}
                route = .onboarding
            }
        } catch {
            profile = nil
            self.error = "Could not load your Moné profile. Please try logging in again."
            do { try await supabase.auth.signOut(scope: .local) } catch {}
            route = .onboarding
        }

        isLoading = false
    }

    func saveName(_ name: String) async {
        guard let userId = supabase.auth.currentSession?.user.id else {
            error = "No active session."
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            error = "Name must be at least 2 characters."
            return
        }

        isLoading = true
        error = nil

        do {
            let data = ProfileUpsert(
                id: userId,
                phone: normalizedCurrentPhone(),
                email: normalizedCurrentEmail(),
                fullName: trimmed,
                onboardingStep: "agendaEducation",
                onboardingCompleted: false
            )
            _ = try await supabase
                .from("profiles")
                .upsert(data)
                .execute()

            profile = Profile(
                id: userId,
                phone: normalizedCurrentPhone(),
                email: normalizedCurrentEmail(),
                fullName: trimmed,
                onboardingStep: "agendaEducation",
                onboardingCompleted: false
            )
            clearRecentlyDeletedUserID(userId.uuidString)
            clearRecentlyDeletedIdentifiers()
            isReturningUser = false
            nextOnboardingStep = .agendaEducation
            route = .onboarding
        } catch {
            self.error = "Failed to save. Please try again."
        }

        isLoading = false
    }

    func signOut() async {
        isLoading = true
        do {
            try await supabase.auth.signOut()
        } catch {
            do { try await supabase.auth.signOut(scope: .local) } catch {}
        }
        profile = nil
        error = nil
        isReturningUser = false
        nextOnboardingStep = .agendaEducation
        shouldForceWelcomeOnboarding = true
        onboardingResetToken = UUID()
        route = .onboarding
        isLoading = false
    }
    
    func startAuthenticationFromProfile() {
        error = nil
        shouldForceWelcomeOnboarding = false
        route = .auth
    }

    /// Saves name for a newly signed-up user without changing the route.
    /// Called from SignUpSheet after OTP verification when no profile exists.
    func completeSignUp(name: String) async throws {
        guard let userId = supabase.auth.currentSession?.user.id else {
            throw URLError(.userAuthenticationRequired)
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let data = ProfileUpsert(
            id: userId,
            phone: normalizedCurrentPhone(),
            email: normalizedCurrentEmail(),
            fullName: trimmed,
            onboardingStep: "dashboard",
            onboardingCompleted: true
        )
        _ = try await supabase.from("profiles").upsert(data).execute()
        profile = Profile(
            id: userId,
            phone: normalizedCurrentPhone(),
            email: normalizedCurrentEmail(),
            fullName: trimmed,
            onboardingStep: "dashboard",
            onboardingCompleted: true
        )
        isReturningUser = false
    }

    func completeOnboarding() async {
        guard let userId = supabase.auth.currentSession?.user.id,
              let fullName = profile?.fullName,
              !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        do {
            let data = ProfileUpsert(
                id: userId,
                phone: profile?.phone ?? normalizedCurrentPhone(),
                email: profile?.email ?? normalizedCurrentEmail(),
                fullName: fullName,
                onboardingStep: "dashboard",
                onboardingCompleted: true
            )
            _ = try await supabase
                .from("profiles")
                .upsert(data)
                .execute()

            profile = Profile(
                id: userId,
                phone: profile?.phone ?? normalizedCurrentPhone(),
                email: profile?.email ?? normalizedCurrentEmail(),
                fullName: fullName,
                onboardingStep: "dashboard",
                onboardingCompleted: true
            )
        } catch {
            self.error = "Failed to finish setup. Please try again."
        }
    }

    func updateOnboardingProgress(to step: AppViewModel.OnboardingStep) async {
        guard step != .complete,
              let userId = supabase.auth.currentSession?.user.id,
              let fullName = profile?.fullName,
              !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let stepName = onboardingStepName(for: step)
        guard profile?.onboardingStep != stepName else { return }

        do {
            let data = ProfileUpsert(
                id: userId,
                phone: profile?.phone ?? normalizedCurrentPhone(),
                email: profile?.email ?? normalizedCurrentEmail(),
                fullName: fullName,
                onboardingStep: stepName,
                onboardingCompleted: false
            )
            _ = try await supabase
                .from("profiles")
                .upsert(data)
                .execute()

            profile = Profile(
                id: userId,
                phone: profile?.phone ?? normalizedCurrentPhone(),
                email: profile?.email ?? normalizedCurrentEmail(),
                fullName: fullName,
                onboardingStep: stepName,
                onboardingCompleted: false
            )
        } catch {}
    }

    func deleteAccount() async {
        guard let session = supabase.auth.currentSession else {
            error = "Please sign in again before deleting your account."
            route = .auth
            return
        }

        isDeletingAccount = true
        error = nil

        do {
            let endpoint = SupabaseConfig.url
                .appendingPathComponent("functions")
                .appendingPathComponent("v1")
                .appendingPathComponent("delete-account")

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                error = "We couldn't delete your account. Please try again."
                isDeletingAccount = false
                return
            }

            do { try await supabase.auth.signOut(scope: .local) } catch {}

            profile = nil
            isReturningUser = false
            nextOnboardingStep = .agendaEducation
            shouldForceWelcomeOnboarding = true
            markRecentlyDeletedUserID(session.user.id.uuidString)
            markRecentlyDeletedIdentifiers(currentSessionIdentifiers(session))
            onboardingResetToken = UUID()
            route = .onboarding
        } catch {
            self.error = "We couldn't delete your account. Please check your connection and try again."
        }

        isDeletingAccount = false
    }

    private func markRecentlyDeletedUserID(_ userId: String) {
        var ids = recentlyDeletedUserIDs
        ids.insert(userId)
        recentlyDeletedUserIDs = ids
    }

    private func clearRecentlyDeletedUserID(_ userId: String) {
        var ids = recentlyDeletedUserIDs
        ids.remove(userId)
        recentlyDeletedUserIDs = ids
    }

    private func markRecentlyDeletedIdentifiers(_ identifiers: [String]) {
        var storedIdentifiers = recentlyDeletedIdentifiers
        storedIdentifiers.formUnion(identifiers)
        recentlyDeletedIdentifiers = storedIdentifiers
    }

    private func clearRecentlyDeletedIdentifiers() {
        recentlyDeletedIdentifiers = []
    }

    private func currentSessionIdentifiers(_ session: Session) -> [String] {
        [session.user.email, session.user.phone]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func resetStaleProfileAfterDeletion(userId: UUID) async {
        let reset = ProfileReset(
            id: userId,
            phone: normalizedCurrentPhone(),
            email: normalizedCurrentEmail(),
            fullName: nil,
            onboardingStep: "name",
            onboardingCompleted: false
        )

        do {
            _ = try await supabase
                .from("profiles")
                .upsert(reset)
                .execute()
        } catch {}

        profile = Profile(
            id: userId,
            phone: normalizedCurrentPhone(),
            email: normalizedCurrentEmail(),
            fullName: nil,
            onboardingStep: "name",
            onboardingCompleted: false
        )
        isReturningUser = false
    }

    private func onboardingStep(from value: String?) -> AppViewModel.OnboardingStep {
        switch value {
        case "agendaEducation", "primaryAgenda", "secondaryAgenda", "welcome", "dataPrivacy", "auth":
            return .agendaEducation
        case "methodSelection", "setupMethod":
            return .methodSelection
        case "aaConsent": return .aaConsent
        case "phoneOtp": return .phoneOtp
        case "aaFetching", "buildingMoneyMap": return .aaFetching
        case "processing", "confirmFindings", "goalSetup": return .processing
        case "storageChoice": return .storageChoice
        case "dashboardTour": return .dashboardTour
        case "dashboard": return .complete
        default: return .agendaEducation
        }
    }

    private func onboardingStepName(for step: AppViewModel.OnboardingStep) -> String {
        switch step {
        case .agendaEducation: return "agendaEducation"
        case .methodSelection: return "methodSelection"
        case .aaConsent: return "aaConsent"
        case .phoneOtp: return "phoneOtp"
        case .aaFetching: return "aaFetching"
        case .processing: return "processing"
        case .storageChoice: return "storageChoice"
        case .dashboardTour: return "dashboardTour"
        case .complete: return "dashboard"
        }
    }
}
