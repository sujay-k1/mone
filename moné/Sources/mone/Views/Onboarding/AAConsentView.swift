import SwiftUI
import Supabase
import SafariServices
import UIKit

struct AAConsentView: View {
    private static let sandboxMobileNumber = "8828290489"

    @Environment(AppViewModel.self) private var appVM
    @State private var mobileNumber = ""
    @State private var consentURL: URL?
    @State private var consentId: String?
    @State private var consentStatus: String?
    @State private var requestedFiTypeCount: Int?
    @State private var consentMobileDigits: String?
    @State private var copiedConsentURL = false
    @State private var showConsentBrowser = false
    @State private var isCreatingConsent = false
    @State private var errorMessage: String?
    @State private var parserArtifactId = "PASTE_ARTIFACT_ID_HERE"
    @State private var isParsingArtifact = false
    @State private var parserSummary: ParseSetuFIArtifactResponse?
    @State private var parserErrorMessage: String?
    @State private var parserHTTPStatus: Int?
    @State private var isCheckingFipStatus = false
    @State private var fipStatusResponse: SetuFIPStatusResponse?
    @State private var fipStatusErrorMessage: String?
    @State private var fipStatusHTTPStatus: Int?
    @State private var fipStatusRawPreview: String?
    @FocusState private var isMobileFocused: Bool

    let requested: [(icon: String, label: String)] = [
        ("arrow.left.arrow.right", "Recent bank transactions"),
        ("chart.bar",              "Income patterns"),
        ("repeat",                 "Recurring payments"),
        ("creditcard",             "Credit card payments"),
        ("calendar",               "Upcoming obligations")
    ]

    let creates: [(icon: String, label: String)] = [
        ("banknote",               "Income map"),
        ("list.bullet.clipboard",  "Obligations & subscriptions"),
        ("flag",                   "Goal allocations"),
        ("gauge.with.needle",      "Safe-to-spend"),
        ("shield",                 "Financial health signals")
    ]

    private var mobileDigits: String {
        mobileNumber.filter(\.isNumber)
    }

    private var isMobileValid: Bool {
        mobileDigits.count == 10
    }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connect\nwith consent.")
                            .font(.moneDisplayMd)
                            .foregroundStyle(Color.monePrimary)
                        Text("Secure, one-time read access via Account Aggregator (RBI regulated).")
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    .padding(.top, 60)

                    // What moné requests
                    ConsentSection(
                        title: "What moné requests",
                        items: requested
                    )

                    // What moné creates
                    ConsentSection(
                        title: "What moné creates",
                        items: creates
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOBILE NUMBER")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                Text("+91")
                                    .font(.moneBodyLg)
                                    .foregroundStyle(Color.monePrimary)

                                TextField(Self.sandboxMobileNumber, text: $mobileNumber)
                                    .focused($isMobileFocused)
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                                    .font(.system(size: 22, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.monePrimary)
                                    .tint(Color.monePrimary)
                                    .onChange(of: mobileNumber) { _, newValue in
                                        let digits = newValue.filter(\.isNumber)
                                        if digits != newValue || digits.count > 10 {
                                            mobileNumber = String(digits.prefix(10))
                                        }
                                        if let consentMobileDigits, digits != consentMobileDigits {
                                            resetConsentDebugState()
                                        }
                                        errorMessage = nil
                                    }
                            }
                            .padding(.bottom, 14)

                            Rectangle()
                                .fill(Color.moneStrokeMid)
                                .frame(height: 1)
                        }
                    }

                    // Privacy note
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(Color.moneHealthy)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Raw data is transient")
                                .font(.moneHLSm)
                                .foregroundStyle(Color.monePrimary)
                            Text("moné reads your data once, derives your MoneyMap, then discards the raw data. Only the MoneyMap is stored on your device.")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)
                        }
                    }
                    .padding(MoneSpacing.cardSm)
                    .moneCard()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneRisk)
                    }

                    if consentURL != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Consent opens in a secure in-app browser. Close it when you finish, then continue.")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneSecondary)

                            // Temporary Setu AA sandbox debug controls. Setu owns the OTP
                            // web form; use external Safari if in-app Safari has OTP input issues.
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SETU DEBUG")
                                    .font(.moneLabelCaps)
                                    .tracking(2)
                                    .foregroundStyle(Color.moneTertiary)

                                VStack(alignment: .leading, spacing: 6) {
                                    if let consentId {
                                        debugRow(label: "Consent", value: consentId)
                                    }

                                    if let consentStatus {
                                        debugRow(label: "Status", value: consentStatus)
                                    }

                                    if let requestedFiTypeCount {
                                        debugRow(label: "FI types", value: "\(requestedFiTypeCount)")
                                    }

                                    if let consentMobileDigits {
                                        debugRow(label: "Mobile", value: "ending \(String(consentMobileDigits.suffix(4)))")
                                    }

                                    debugRow(label: "URL", value: "available")
                                }

                                HStack(spacing: 10) {
                                    Button {
                                        copyConsentURL()
                                    } label: {
                                        Label(copiedConsentURL ? "Copied" : "Copy URL", systemImage: copiedConsentURL ? "checkmark" : "doc.on.doc")
                                            .font(.moneBodySm)
                                    }
                                    .foregroundStyle(Color.monePrimary)

                                    Button {
                                        openConsentInExternalSafari()
                                    } label: {
                                        Label("Open Safari", systemImage: "safari")
                                            .font(.moneBodySm)
                                    }
                                    .foregroundStyle(Color.monePrimary)
                                }
                            }
                            .padding(MoneSpacing.cardSm)
                            .moneCard()
                        }
                    }

                    // Temporary developer-only Setu parser trigger. Remove before
                    // production AA UX; this exposes only parser summary counts.
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DEVELOPER DEBUG")
                            .font(.moneLabelCaps)
                            .tracking(2)
                            .foregroundStyle(Color.moneTertiary)

                        Text("Check Setu sandbox FIP availability, then parse one stored Setu FI artifact.")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)

                        Button {
                            Task { await checkSetuFIPStatus() }
                        } label: {
                            Label(isCheckingFipStatus ? "Checking Setu FIP status..." : "Debug: Check Setu FIP status", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.moneBodySm)
                        }
                        .foregroundStyle(Color.monePrimary)
                        .disabled(isCheckingFipStatus)
                        .opacity(isCheckingFipStatus ? 0.5 : 1)

                        if let fipStatusResponse {
                            VStack(alignment: .leading, spacing: 12) {
                                if let fipStatusHTTPStatus {
                                    debugRow(label: "HTTP", value: "\(fipStatusHTTPStatus)")
                                }

                                ForEach(fipStatusResponse.fips) { fip in
                                    VStack(alignment: .leading, spacing: 6) {
                                        debugRow(label: "FIP", value: fip.fipId)
                                        debugRow(label: "Name", value: fip.name)

                                        if let status = fip.status {
                                            debugRow(label: "Status", value: status)
                                        }

                                        if !fip.fiTypes.isEmpty {
                                            debugRow(label: "FI types", value: fip.fiTypes.joined(separator: ", "))
                                        }

                                        if let dataFetchSuccessRate = fip.dataFetchSuccessRate {
                                            debugRow(label: "Fetch", value: formattedRate(dataFetchSuccessRate))
                                        }

                                        if let consentConversionRate = fip.consentConversionRate {
                                            debugRow(label: "Consent", value: formattedRate(consentConversionRate))
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }

                        if let fipStatusErrorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                if let fipStatusHTTPStatus {
                                    debugRow(label: "HTTP", value: "\(fipStatusHTTPStatus)")
                                }

                                Text(fipStatusErrorMessage)
                                    .font(.moneBodySm)
                                    .foregroundStyle(Color.moneRisk)

                                if let fipStatusRawPreview {
                                    debugRow(label: "Preview", value: fipStatusRawPreview)
                                }
                            }
                        }

                        Divider().background(Color.moneStroke)

                        Text("Parse one stored Setu FI artifact into canonical account and transaction rows.")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)

                        TextField("Artifact ID", text: $parserArtifactId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.monePrimary)
                            .tint(Color.monePrimary)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.moneStrokeMid)
                                    .frame(height: 1)
                            }
                            .onChange(of: parserArtifactId) { _, _ in
                                parserErrorMessage = nil
                                parserSummary = nil
                                parserHTTPStatus = nil
                            }

                        Button {
                            Task { await parseSetuFIArtifact() }
                        } label: {
                            Label(isParsingArtifact ? "Parsing artifact..." : "Parse artifact", systemImage: "hammer")
                                .font(.moneBodySm)
                        }
                        .foregroundStyle(Color.monePrimary)
                        .disabled(isParsingArtifact)
                        .opacity(isParsingArtifact ? 0.5 : 1)

                        if let parserSummary {
                            VStack(alignment: .leading, spacing: 6) {
                                if let parserHTTPStatus {
                                    debugRow(label: "HTTP", value: "\(parserHTTPStatus)")
                                }

                                debugRow(label: "Accounts", value: "\(parserSummary.accountCount)")
                                debugRow(label: "Txns", value: "\(parserSummary.transactionCount)")

                                if let insertedTransactionCount = parserSummary.insertedTransactionCount {
                                    debugRow(label: "Inserted", value: "\(insertedTransactionCount)")
                                }

                                debugRow(label: "FI types", value: parserSummary.fiTypes.joined(separator: ", "))
                            }
                        }

                        if let parserErrorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                if let parserHTTPStatus {
                                    debugRow(label: "HTTP", value: "\(parserHTTPStatus)")
                                }

                                Text(parserErrorMessage)
                                    .font(.moneBodySm)
                                    .foregroundStyle(Color.moneRisk)
                            }
                        }
                    }
                    .padding(MoneSpacing.cardSm)
                    .moneCard()

                    VStack(spacing: MoneSpacing.gap) {
                        MonePrimaryButton(title: isCreatingConsent ? "Starting consent..." : consentURL == nil ? "Continue to consent" : "Open consent again") {
                            Task { await startConsent() }
                        }
                        .opacity(isCreatingConsent || !isMobileValid ? 0.4 : 1)
                        .disabled(isCreatingConsent || !isMobileValid)

                        if consentURL != nil {
                            MoneSecondaryButton(title: "I've completed consent") {
                                appVM.advance()
                            }
                        }

                        MoneSecondaryButton(title: "Choose another method") {
                            appVM.onboardingStep = .methodSelection
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
            .contentShape(Rectangle())
            .onTapGesture { isMobileFocused = false }
        }
        .onAppear {
            if mobileNumber.isEmpty {
                mobileNumber = normalizedSessionPhone()
            }
        }
        .sheet(isPresented: $showConsentBrowser) {
            if let consentURL {
                SafariConsentView(url: consentURL)
                    .ignoresSafeArea()
            }
        }
    }

    private func startConsent() async {
        if consentURL != nil {
            showConsentBrowser = true
            return
        }

        guard isMobileValid else {
            errorMessage = "Enter a valid 10-digit mobile number."
            return
        }

        guard let session = supabase.auth.currentSession else {
            errorMessage = "Please sign in again to continue."
            return
        }

        isCreatingConsent = true
        errorMessage = nil

        do {
            let endpoint = SupabaseConfig.url
                .appendingPathComponent("functions")
                .appendingPathComponent("v1")
                .appendingPathComponent("setu-aa-create-consent")

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(CreateAAConsentRequest(mobileNumber: mobileDigits))

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Could not start consent. Please try again."
                isCreatingConsent = false
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                errorMessage = friendlyConsentError(from: data)
                isCreatingConsent = false
                return
            }

            let result = try JSONDecoder().decode(CreateAAConsentResponse.self, from: data)
            guard let url = URL(string: result.consentUrl) else {
                errorMessage = "Consent link was invalid. Please try again."
                isCreatingConsent = false
                return
            }

            consentURL = url
            consentId = result.consentId
            consentStatus = result.status
            requestedFiTypeCount = result.requestedFiTypeCount
            consentMobileDigits = mobileDigits
            copiedConsentURL = false

            print("setu_consent_debug", [
                "consentId": result.consentId,
                "status": result.status,
                "requestedFiTypeCount": String(result.requestedFiTypeCount ?? 0),
                "mobileEnding": String(mobileDigits.suffix(4)),
                "hasConsentUrl": "true"
            ])

            showConsentBrowser = true
        } catch {
            errorMessage = "Could not start consent. Please check your connection and try again."
        }

        isCreatingConsent = false
    }

    private func checkSetuFIPStatus() async {
        guard let session = supabase.auth.currentSession else {
            fipStatusErrorMessage = "Please sign in again to check FIP status."
            return
        }

        isCheckingFipStatus = true
        fipStatusErrorMessage = nil
        fipStatusResponse = nil
        fipStatusHTTPStatus = nil
        fipStatusRawPreview = nil

        do {
            let endpoint = SupabaseConfig.url
                .appendingPathComponent("functions")
                .appendingPathComponent("v1")
                .appendingPathComponent("setu-aa-fip-status")

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(SetuFIPStatusRequest(
                fipIds: ["setu-fip", "setu-fip-2"],
                expanded: true
            ))

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                fipStatusErrorMessage = "Could not check Setu FIP status. Please try again."
                isCheckingFipStatus = false
                return
            }

            fipStatusHTTPStatus = httpResponse.statusCode

            guard (200..<300).contains(httpResponse.statusCode) else {
                fipStatusErrorMessage = friendlyFIPStatusError(from: data, statusCode: httpResponse.statusCode)
                isCheckingFipStatus = false
                return
            }

            do {
                fipStatusResponse = try JSONDecoder().decode(SetuFIPStatusResponse.self, from: data)
            } catch {
                fipStatusErrorMessage = "FIP status returned an unexpected response. Confirm the latest setu-aa-fip-status function is deployed."
                fipStatusRawPreview = safeResponsePreview(from: data)
            }
        } catch let urlError as URLError {
            fipStatusErrorMessage = "Could not reach FIP status function. Network error \(urlError.code.rawValue): \(urlError.localizedDescription)"
        } catch {
            fipStatusErrorMessage = "Could not reach FIP status function. \(error.localizedDescription)"
        }

        isCheckingFipStatus = false
    }

    private func parseSetuFIArtifact() async {
        let artifactId = parserArtifactId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !artifactId.isEmpty, artifactId != "PASTE_ARTIFACT_ID_HERE" else {
            parserErrorMessage = "Paste a financial data artifact ID first."
            return
        }

        guard let session = supabase.auth.currentSession else {
            parserErrorMessage = "Please sign in again to parse the artifact."
            return
        }

        isParsingArtifact = true
        parserErrorMessage = nil
        parserSummary = nil
        parserHTTPStatus = nil

        do {
            let endpoint = SupabaseConfig.url
                .appendingPathComponent("functions")
                .appendingPathComponent("v1")
                .appendingPathComponent("parse-setu-fi-artifact")

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(ParseSetuFIArtifactRequest(artifactId: artifactId))

            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 180
            configuration.timeoutIntervalForResource = 240
            let parserSession = URLSession(configuration: configuration)
            let (data, response) = try await parserSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                parserErrorMessage = "Could not parse artifact. Please try again."
                isParsingArtifact = false
                return
            }

            parserHTTPStatus = httpResponse.statusCode

            guard (200..<300).contains(httpResponse.statusCode) else {
                parserErrorMessage = friendlyParserError(from: data, statusCode: httpResponse.statusCode)
                isParsingArtifact = false
                return
            }

            do {
                parserSummary = try JSONDecoder().decode(ParseSetuFIArtifactResponse.self, from: data)
            } catch {
                parserErrorMessage = "Parser returned an unexpected response. Confirm the latest parse-setu-fi-artifact function is deployed."
            }
        } catch let urlError as URLError {
            parserErrorMessage = "Could not reach parser function. Network error \(urlError.code.rawValue): \(urlError.localizedDescription)"
        } catch {
            parserErrorMessage = "Could not reach parser function. \(error.localizedDescription)"
        }

        isParsingArtifact = false
    }

    private func normalizedSessionPhone() -> String {
        guard let phone = supabase.auth.currentSession?.user.phone else {
            return Self.sandboxMobileNumber
        }
        let digits = phone.filter(\.isNumber)

        if digits.count == 10 {
            return digits
        }

        if digits.count == 12 && digits.hasPrefix("91") {
            return String(digits.dropFirst(2))
        }

        return Self.sandboxMobileNumber
    }

    private func friendlyConsentError(from data: Data) -> String {
        if let payload = try? JSONDecoder().decode(AAConsentErrorResponse.self, from: data),
           !payload.error.isEmpty {
            if let debugMessage = payload.debugMessage, !debugMessage.isEmpty {
                return debugMessage
            }

            if let detailMessage = payload.details?.message, !detailMessage.isEmpty {
                return detailMessage
            }

            if let traceId = payload.traceId, !traceId.isEmpty {
                return "\(payload.error). Trace ID: \(traceId)"
            }

            return payload.error
        }

        return "Could not start consent. Please try again."
    }

    private func friendlyParserError(from data: Data, statusCode: Int) -> String {
        if let payload = try? JSONDecoder().decode(ParseSetuFIArtifactErrorResponse.self, from: data),
           let message = payload.safeMessage {
            return message
        }

        if statusCode == 404 {
            return "Parser function or artifact was not found. Confirm the function is deployed and the artifact ID belongs to this user."
        }

        if statusCode == 401 || statusCode == 403 {
            return "Session was rejected. Sign in again and retry."
        }

        return "Parser failed. Check Supabase function logs for the safe server-side error."
    }

    private func friendlyFIPStatusError(from data: Data, statusCode: Int) -> String {
        if let payload = try? JSONDecoder().decode(SetuFIPStatusErrorResponse.self, from: data),
           let message = payload.safeMessage {
            return message
        }

        if statusCode == 404 {
            return "FIP status function was not found. Confirm it is deployed to this Supabase project."
        }

        if statusCode == 401 || statusCode == 403 {
            return "Session was rejected. Sign in again and retry."
        }

        return "Could not check Setu FIP status. Check Supabase function logs for the safe server-side error."
    }

    private func formattedRate(_ value: Double) -> String {
        if value <= 1 {
            return "\(Int((value * 100).rounded()))%"
        }

        return "\(value)"
    }

    private func safeResponsePreview(from data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            return "Non-text response"
        }

        return String(text.prefix(240))
    }

    @ViewBuilder
    private func debugRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneTertiary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private func copyConsentURL() {
        guard let consentURL else { return }
        UIPasteboard.general.string = consentURL.absoluteString
        copiedConsentURL = true
    }

    private func openConsentInExternalSafari() {
        guard let consentURL else { return }
        UIApplication.shared.open(consentURL)
    }

    private func resetConsentDebugState() {
        consentURL = nil
        consentId = nil
        consentStatus = nil
        requestedFiTypeCount = nil
        consentMobileDigits = nil
        copiedConsentURL = false
    }
}

private struct CreateAAConsentRequest: Encodable {
    let mobileNumber: String
}

private struct CreateAAConsentResponse: Decodable {
    let consentId: String
    let consentUrl: String
    let status: String
    let requestedFiTypeCount: Int?
}

private struct AAConsentErrorResponse: Decodable {
    let error: String
    let debugMessage: String?
    let traceId: String?
    let details: AAConsentErrorDetails?
}

private struct AAConsentErrorDetails: Decodable {
    let message: String?
}

private struct SetuFIPStatusRequest: Encodable {
    let fipIds: [String]
    let expanded: Bool
}

private struct SetuFIPStatusResponse: Decodable {
    let traceId: String?
    let fips: [SetuFIPStatus]
    let count: Int?
}

private struct SetuFIPStatus: Decodable, Identifiable {
    let name: String
    let fipId: String
    let fiTypes: [String]
    let institutionType: String?
    let status: String?
    let consentConversionRate: Double?
    let dataFetchSuccessRate: Double?

    var id: String {
        fipId
    }
}

private struct SetuFIPStatusErrorResponse: Decodable {
    let error: String?
    let message: String?
    let msg: String?

    var safeMessage: String? {
        [error, message, msg]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct ParseSetuFIArtifactRequest: Encodable {
    let artifactId: String
}

private struct ParseSetuFIArtifactResponse: Decodable {
    let accountCount: Int
    let transactionCount: Int
    let insertedTransactionCount: Int?
    let fiTypes: [String]
}

private struct ParseSetuFIArtifactErrorResponse: Decodable {
    let error: String?
    let message: String?
    let msg: String?

    var safeMessage: String? {
        [error, message, msg]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct SafariConsentView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = UIColor(Color.moneBackground)
        controller.preferredControlTintColor = UIColor(Color.monePrimary)
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct ConsentSection: View {
    let title: String
    let items: [(icon: String, label: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: MoneSpacing.gap) {
            Text(title.uppercased())
                .moneLabelCaps()
                .padding(.bottom, 4)

            VStack(spacing: 2) {
                ForEach(items, id: \.label) { item in
                    HStack(spacing: MoneSpacing.gutter) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.moneSecondary)
                            .frame(width: 24)
                        Text(item.label)
                            .font(.moneBodyMd)
                            .foregroundStyle(Color.monePrimary)
                        Spacer()
                    }
                    .padding(.vertical, 10)

                    if item.label != items.last?.label {
                        Divider().background(Color.moneStroke)
                    }
                }
            }
            .padding(.horizontal, MoneSpacing.cardSm)
            .moneCard()
        }
    }
}

#Preview {
    AAConsentView()
        .environment(AppViewModel())
}
