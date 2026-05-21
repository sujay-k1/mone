import SwiftUI
import UIKit

struct PayView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var scannerID = UUID()
    @State private var scannedPayload: UPIQRPayload?

    @State private var showPaymentSheet = false
    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedApp: UPIApp?
    @State private var installedUPIApps: [UPIApp] = []

    @State private var paymentErrorMessage: String?

    @FocusState private var amountFocused: Bool
    @FocusState private var descriptionFocused: Bool

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
        .sheet(isPresented: $showPaymentSheet, onDismiss: {
            restartScannerIfNeeded()
        }) {
            if let scannedPayload {
                paymentSheet(payload: scannedPayload)
                    .presentationDetents([.fraction(0.74), .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("moné")
                        .font(.moneLabelCaps)
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.72))

                    Text("Pay with Pause")
                        .font(.moneHLMd)
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    scannerID = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
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
                VStack(alignment: .leading, spacing: MoneSpacing.section) {
                    sheetHeader(payload: payload)

                    vendorCard(payload: payload)

                    inputFields

                    upiAppSelector

                    Spacer(minLength: 96)
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 20)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("PAYMENT DETAILS")
                .moneLabelCaps()

            Text("Review the amount, add a note, then choose where to pay from.")
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
    }

    private func vendorCard(payload: UPIQRPayload) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.moneSurface)
                        .frame(width: 48, height: 48)

                    Image(systemName: categoryIcon(inferredCategory))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.monePrimary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(payload.displayName)
                        .font(.moneBodyLg.weight(.semibold))
                        .foregroundStyle(Color.monePrimary)
                        .lineLimit(2)

                    Text(payload.payeeVPA)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(inferredCategory.rawValue)
                            .font(.moneLabelCaps)
                            .foregroundStyle(Color.moneSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.moneSurface)
                            .clipShape(Capsule())

                        if let merchantCode = payload.merchantCode {
                            Text("MCC \(merchantCode)")
                                .font(.moneLabelCaps)
                                .foregroundStyle(Color.moneTertiary)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(MoneSpacing.cardLg)
        .background(Color.moneSurface)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous)
                .strokeBorder(Color.moneStroke, lineWidth: 1)
        )
    }

    private var inputFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .moneLabelCaps()

                HStack(spacing: 8) {
                    Text("₹")
                        .font(.moneAmtMd)
                        .foregroundStyle(Color.moneSecondary)

                    TextField("0", text: $amountText)
                        .font(.moneAmtMd)
                        .foregroundStyle(Color.monePrimary)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .tint(Color.moneActionFill)
                        .onTapGesture {
                            amountFocused = true
                        }
                }
                .padding(MoneSpacing.cardSm)
                .background(Color.moneSurface)
                .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                        .strokeBorder(Color.moneStroke, lineWidth: 1)
                )

                if let guidance {
                    guidanceCard(guidance)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .moneLabelCaps()

                TextField("What is this for?", text: $descriptionText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.monePrimary)
                    .focused($descriptionFocused)
                    .tint(Color.moneActionFill)
                    .padding(MoneSpacing.cardSm)
                    .background(Color.moneSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                            .strokeBorder(Color.moneStroke, lineWidth: 1)
                    )
                    .onTapGesture {
                        descriptionFocused = true
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: guidance)
    }

    private func guidanceCard(_ guidance: PaymentGuidance) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: guidanceIcon(guidance.severity))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(guidanceColor(guidance.severity))

                VStack(alignment: .leading, spacing: 6) {
                    Text(guidance.title)
                        .font(.moneBodyMd.weight(.semibold))
                        .foregroundStyle(Color.monePrimary)

                    Text(guidance.body)
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneSecondary)
                        .lineSpacing(3)

                    if let metric = guidance.metric {
                        Text(metric)
                            .font(.moneLabelCaps)
                            .foregroundStyle(guidanceColor(guidance.severity))
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
        }
        .padding(MoneSpacing.cardSm)
        .background(guidanceColor(guidance.severity).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                .strokeBorder(guidanceColor(guidance.severity).opacity(0.35), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Pay using")
                .moneLabelCaps()

            if installedUPIApps.isEmpty {
                Text("No supported UPI apps detected on this iPhone.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                    .padding(MoneSpacing.cardSm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.moneSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
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
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.monePrimary : Color.moneSurface)
                        .frame(width: 56, height: 56)

                    Image(systemName: app.systemIconName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.moneBackground : Color.monePrimary)
                }
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.monePrimary : Color.moneStroke, lineWidth: 1)
                )

                Text(app.displayName)
                    .font(.caption2)
                    .foregroundStyle(Color.moneSecondary)
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
                Image(systemName: "arrow.up.forward.app.fill")
                Text("Continue to pay")
            }
            .font(.headline)
            .foregroundStyle(Color.moneBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canContinue ? Color.monePrimary : Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.55)
    }
    
    private func paymentButtonDock(payload: UPIQRPayload) -> some View {
        VStack(spacing: 10) {
            continueButton(payload: payload)
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 12)

            Text(canContinue ? "You’ll continue in the selected UPI app." : "Enter an amount to continue.")
                .font(.caption)
                .foregroundStyle(Color.moneSecondary)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.moneBackground.opacity(0.78))
                )
        )
    }

    private func handleDetectedCode(_ rawValue: String) -> Bool {
        guard let payload = UPIQRParser.parse(rawValue) else {
            return false
        }

        scannedPayload = payload

        amountText = payload.amount.map { amount in
            amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount))
                : String(amount)
        } ?? ""

        descriptionText = payload.transactionNote ?? ""

        installedUPIApps = UPIAppDiscoveryService.installedApps()
        selectedApp = installedUPIApps.first

        showPaymentSheet = true

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
                showPaymentSheet = false
            } else {
                paymentErrorMessage = "Could not open \(app.displayName). Please try another UPI app."
            }
        }
    }

    private func resetAndScanAgain() {
        showPaymentSheet = false
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
