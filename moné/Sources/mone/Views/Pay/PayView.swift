import SwiftUI
import UIKit

struct PayView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var scannerID = UUID()
    @State private var scannedPayload: UPIQRPayload?

    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedApp: UPIApp?
    @State private var installedUPIApps: [UPIApp] = []

    @State private var paymentErrorMessage: String?

    @FocusState private var amountFocused: Bool
    @FocusState private var descriptionFocused: Bool

    private var currentMonthTag: String {
        let sts = appVM.safeToSpend
        let raw = sts.weekly - sts.spentThisWeek
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let amount = formatter.string(from: NSNumber(value: abs(raw))) ?? "\(Int(abs(raw)))"
        if raw >= 0 {
            return "₹\(amount) safe to spend"
        } else {
            return "₹\(amount) over budget"
        }
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ""))
    }

    private var inferredCategory: TransactionCategory {
        guard let scannedPayload else { return .other }

        return PaymentGuidanceEngine.inferCategory(
            from: scannedPayload,
            description: descriptionText
        )
    }

    private var guidance: PaymentGuidance? {
        guard
            let scannedPayload,
            let amount = parsedAmount,
            amount > 0
        else {
            return nil
        }

        return PaymentGuidanceEngine.guidance(
            payload: scannedPayload,
            amount: amount,
            description: descriptionText,
            category: inferredCategory,
            moneyMap: appVM.moneyMap,
            spentThisWeek: appVM.spentThisWeek
        )
    }

    private var canContinue: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        guard selectedApp != nil else { return false }
        return true
    }

    var body: some View {
        ZStack {
            QRScannerView(
                onCodeDetected: { rawValue in
                    handleDetectedCode(rawValue)
                },
                onPermissionDenied: {
                    paymentErrorMessage = "Camera permission is needed to scan UPI QR codes."
                }
            )
            .id(scannerID)
            .ignoresSafeArea()

            topCameraChrome
        }
        .onAppear {
            installedUPIApps = UPIAppDiscoveryService.installedApps()
        }
        .sheet(item: $scannedPayload, onDismiss: {
            MoneTactileFeedback.playDampedCardCollapse()
            restartScannerIfNeeded()
        }) { payload in
            paymentSheet(payload: payload)
                .presentationDetents([.fraction(0.74), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .alert(
            "Payment unavailable",
            isPresented: Binding(
                get: { paymentErrorMessage != nil },
                set: { if !$0 { paymentErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                paymentErrorMessage = nil
            }
        } message: {
            Text(paymentErrorMessage ?? "")
        }
    }

    private var topCameraChrome: some View {
        VStack {
            HStack {
                DashboardHeader(title: "Pay with Pause", tag: currentMonthTag, labelColor: .moneSecondary)

                Button {
                    scannerID = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.monePrimary)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func paymentSheet(payload: UPIQRPayload) -> some View {
        ZStack {
            Color.moneBackground
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    sheetHeader(payload: payload)

                    vendorCard(payload: payload)

                    inputFields

                    upiAppSelector

                    Spacer(minLength: 96)
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .safeAreaInset(edge: .bottom) {
            paymentButtonDock(payload: payload)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                amountFocused = true
            }
        }
    }

    private func sheetHeader(payload: UPIQRPayload) -> some View {
        DashboardHeader(
            title: "Pay with Pause",
            subtitle: "Review the amount, add a note, then choose where to pay from.",
            tag: currentMonthTag,
            labelColor: .moneSecondary
        )
    }

    private func vendorCard(payload: UPIQRPayload) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.moneSurfaceEl)
                    .frame(width: 56, height: 56)

                Image(systemName: categoryIcon(inferredCategory))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(payload.displayName)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                    .lineLimit(2)

                Text(payload.payeeVPA)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(inferredCategory.rawValue.uppercased())
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.moneSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.moneStroke, lineWidth: 1))

                    if let merchantCode = payload.merchantCode {
                        Text("MCC \(merchantCode)")
                            .font(.moneLabelCaps)
                            .foregroundStyle(Color.moneTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(MoneSpacing.cardLg)
        .moneCard(radius: MoneRadius.xxl, elevated: true)
    }

    private var inputFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("AMOUNT")
                    .moneLabelCaps(color: .moneTertiary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("₹")
                        .font(.moneAmtMd)
                        .foregroundStyle(Color.moneSecondary)

                    TextField("0", text: $amountText)
                        .font(.moneAmtLg)
                        .foregroundStyle(Color.monePrimary)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .tint(Color.moneActionFill)
                        .onTapGesture { amountFocused = true }
                }
                .padding(MoneSpacing.cardLg)
                .moneCard(radius: MoneRadius.xl, elevated: true)

                if let guidance {
                    guidanceCard(guidance)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("NOTE")
                    .moneLabelCaps(color: .moneTertiary)

                TextField("What is this for?", text: $descriptionText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.monePrimary)
                    .focused($descriptionFocused)
                    .tint(Color.moneActionFill)
                    .padding(MoneSpacing.cardLg)
                    .moneCard(radius: MoneRadius.xl, elevated: true)
                    .onTapGesture { descriptionFocused = true }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: guidance)
    }

    private func guidanceCard(_ guidance: PaymentGuidance) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: guidanceIcon(guidance.severity))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(guidanceColor(guidance.severity))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(guidance.title)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)

                Text(guidance.body)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let metric = guidance.metric {
                    Text(metric)
                        .font(.moneLabelCaps)
                        .foregroundStyle(guidanceColor(guidance.severity))
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(MoneSpacing.cardLg)
        .background(guidanceColor(guidance.severity).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous)
                .strokeBorder(guidanceColor(guidance.severity).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func hideKeyboard() {
        amountFocused = false
        descriptionFocused = false

        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var upiAppSelector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PAY USING")
                .moneLabelCaps(color: .moneTertiary)

            if installedUPIApps.isEmpty {
                Text("No supported UPI apps detected on this iPhone.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .padding(MoneSpacing.cardLg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .moneCard(radius: MoneRadius.xl, elevated: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(installedUPIApps) { app in
                            upiAppIcon(app)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func upiAppIcon(_ app: UPIApp) -> some View {
        let isSelected = selectedApp == app

        return Button {
            hideKeyboard()
            selectedApp = app
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.monePrimary : Color.moneSurfaceEl)
                        .frame(width: 60, height: 60)

                    CompanyLogoView(
                        query: app.displayName,
                        aliases: [app.id, app.scheme],
                        fallbackSystemName: app.systemIconName,
                        padding: 3
                    )
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .grayscale(isSelected ? 0.15 : 0)
                }
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.monePrimary : Color.moneStroke, lineWidth: 1)
                )

                Text(app.displayName)
                    .font(.moneLabelCaps)
                    .foregroundStyle(isSelected ? Color.monePrimary : Color.moneSecondary)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
    }

    private func continueButton(payload: UPIQRPayload) -> some View {
        Button {
            openSelectedUPIApp(payload: payload)
        } label: {
            HStack(spacing: 10) {
                Text("Continue to pay")
                    .font(.moneHLSm)
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(canContinue ? Color.moneActionFg : Color.moneTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(canContinue ? Color.moneActionFill : Color.moneSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(canContinue ? Color.clear : Color.moneStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
    }

    private func paymentButtonDock(payload: UPIQRPayload) -> some View {
        VStack(spacing: 8) {
            continueButton(payload: payload)
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 16)

            Text(canContinue ? "You’ll continue in the selected UPI app." : "Enter an amount and select an app to continue.")
                .font(.moneLabelCaps)
                .foregroundStyle(Color.moneTertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.moneBackground.opacity(0.92))
                .ignoresSafeArea()
        )
    }

    private func handleDetectedCode(_ rawValue: String) -> Bool {
        guard let payload = UPIQRParser.parse(rawValue) else {
            return false
        }

        amountText = payload.amount.map { amount in
            amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount))
                : String(amount)
        } ?? ""

        descriptionText = payload.transactionNote ?? ""

        installedUPIApps = UPIAppDiscoveryService.installedApps()
        selectedApp = installedUPIApps.first

        MoneTactileFeedback.playElasticCardExpand()
        scannedPayload = payload

        return true
    }

    private func openSelectedUPIApp(payload: UPIQRPayload) {
        hideKeyboard()

        guard
            let app = selectedApp,
            let amount = parsedAmount,
            amount > 0,
            let url = app.paymentURL(payload: payload, amount: amount, note: descriptionText)
        else {
            return
        }

        UIApplication.shared.open(url) { success in
            if success {
                scannedPayload = nil
            } else {
                paymentErrorMessage = "Could not open \(app.displayName). Please try another UPI app."
            }
        }
    }

    private func resetAndScanAgain() {
        scannedPayload = nil
        amountText = ""
        descriptionText = ""
        selectedApp = nil
        scannerID = UUID()
    }

    private func restartScannerIfNeeded() {
        scannedPayload = nil
        amountText = ""
        descriptionText = ""
        selectedApp = nil
        scannerID = UUID()
    }

    private func categoryIcon(_ category: TransactionCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .shopping: return "bag"
        case .transport: return "car"
        case .health: return "cross.case"
        case .bills: return "doc.text"
        case .entertainment: return "tv"
        case .subscriptions: return "repeat"
        case .creditCard: return "creditcard"
        case .housing: return "house"
        case .all, .other: return "person.crop.circle.badge.checkmark"
        }
    }

    private func guidanceIcon(_ severity: PaymentGuidance.Severity) -> String {
        switch severity {
        case .calm: return "checkmark.seal"
        case .watch: return "pause.circle"
        case .risk: return "exclamationmark.triangle"
        case .supportive: return "heart.text.square"
        }
    }

    private func guidanceColor(_ severity: PaymentGuidance.Severity) -> Color {
        switch severity {
        case .calm: return Color.monePrimary
        case .watch: return Color.orange
        case .risk: return Color.red
        case .supportive: return Color.blue
        }
    }
}

#Preview {
    PayView()
        .environment(AppViewModel())
}
