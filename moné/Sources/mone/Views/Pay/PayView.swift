import SwiftUI
import UIKit

struct PayView: View {
    @Environment(AppViewModel.self) private var appVM

    @State private var showScanner = false
    @State private var hasAutoOpenedScanner = false
    @State private var scannerErrorMessage: String?

    @State private var scannedPayload: UPIQRPayload?
    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var selectedApp: UPIApp?
    @State private var installedUPIApps: [UPIApp] = []

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

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().ignoresSafeArea()

            if let scannedPayload {
                paymentForm(payload: scannedPayload)
            } else {
                scanRequiredView
            }
        }
        .onAppear {
            installedUPIApps = UPIAppDiscoveryService.installedApps()

            if !hasAutoOpenedScanner {
                hasAutoOpenedScanner = true
                showScanner = true
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                onScan: { rawValue in
                    showScanner = false
                    handleScannedQRCode(rawValue)
                },
                onCancel: {
                    showScanner = false
                },
                onPermissionDenied: {
                    showScanner = false
                    scannerErrorMessage = "Camera permission is needed to scan UPI QR codes. You can enable it from iPhone Settings."
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            "Could not scan QR",
            isPresented: Binding(
                get: { scannerErrorMessage != nil },
                set: { if !$0 { scannerErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                scannerErrorMessage = nil
            }
        } message: {
            Text(scannerErrorMessage ?? "")
        }
    }

    private var scanRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color.monePrimary)

            VStack(spacing: 8) {
                Text("Scan to pay")
                    .font(.moneHLMd)
                    .foregroundStyle(Color.monePrimary)

                Text("Point your camera at a UPI QR code to begin.")
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showScanner = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                    Text("Open camera")
                }
                .font(.headline)
                .foregroundStyle(Color.moneBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.monePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, MoneSpacing.page)

            Spacer()
        }
        .padding(.horizontal, MoneSpacing.page)
    }

    private func paymentForm(payload: UPIQRPayload) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MoneSpacing.section) {

                header

                vendorCard(payload: payload)

                inputFields

                if let guidance {
                    guidanceCard(guidance)
                }

                upiAppSelector

                continueButton(payload: payload)

                Button {
                    resetAndScanAgain()
                } label: {
                    Text("Scan a different QR")
                        .font(.moneBodySm.weight(.medium))
                        .foregroundStyle(Color.moneSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, 16)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("moné")
                    .font(.moneLabelCaps)
                    .tracking(1.5)
                    .foregroundStyle(Color.moneTertiary)

                Text("Pay with Pause")
                    .font(.moneHLMd)
                    .foregroundStyle(Color.monePrimary)
            }

            Spacer()

            Button {
                showScanner = true
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.monePrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.moneSurface)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.moneStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
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
                }
                .padding(MoneSpacing.cardSm)
                .background(Color.moneSurface)
                .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                        .strokeBorder(Color.moneStroke, lineWidth: 1)
                )
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
            }
        }
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

    private var canContinue: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        guard selectedApp != nil else { return false }
        return true
    }

    private func handleScannedQRCode(_ rawValue: String) {
        guard let payload = UPIQRParser.parse(rawValue) else {
            scannerErrorMessage = "This QR does not look like a valid UPI payment QR."
            return
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
    }

    private func openSelectedUPIApp(payload: UPIQRPayload) {
        guard
            let app = selectedApp,
            let amount = parsedAmount,
            amount > 0,
            let url = app.paymentURL(payload: payload, amount: amount, note: descriptionText)
        else {
            return
        }

        UIApplication.shared.open(url) { success in
            if !success {
                scannerErrorMessage = "Could not open \(app.displayName). Please try another UPI app."
            }
        }
    }

    private func resetAndScanAgain() {
        scannedPayload = nil
        amountText = ""
        descriptionText = ""
        selectedApp = nil
        showScanner = true
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
