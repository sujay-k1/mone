import SwiftUI

struct PayView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showScanner = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()
            ContourBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MoneSpacing.section) {

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("moné").font(.moneLabelCaps).tracking(1.5).foregroundStyle(Color.moneTertiary)
                            Text("Pay with Pause").font(.moneHLMd).foregroundStyle(Color.monePrimary)
                        }
                        Spacer()
                        // Nudge setting
                        Menu {
                            ForEach(NudgeIntensity.allCases, id: \.rawValue) { intensity in
                                Button {
                                    appVM.nudgeIntensity = intensity
                                } label: {
                                    HStack {
                                        Text(intensity.rawValue)
                                        if appVM.nudgeIntensity == intensity {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14))
                                Text(appVM.nudgeIntensity.rawValue)
                                    .font(.moneBodySm)
                            }
                            .foregroundStyle(Color.moneSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.moneSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.moneStroke, lineWidth: 1))
                        }
                    }
                    .padding(.top, 16)

                    // QR Scan button
                    Button {
                        showScanner = true
                    } label: {
                        VStack(spacing: MoneSpacing.gap) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 48, weight: .thin))
                                .foregroundStyle(Color.monePrimary)
                            Text("Scan QR code")
                                .font(.moneBodyMd)
                                .foregroundStyle(Color.moneSecondary)
                            Text("or enter details below")
                                .font(.moneBodySm)
                                .foregroundStyle(Color.moneTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color.moneSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.moneStrokeBright, Color.moneStroke],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    // Manual entry
                    VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                        Text("OR ENTER MANUALLY")
                            .moneLabelCaps()

                        // Merchant
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Merchant / Payee")
                                .font(.moneLabelCaps)
                                .tracking(0.8)
                                .foregroundStyle(Color.moneTertiary)
                            TextField("e.g. Third Wave Coffee", text: Bindable(appVM).payMerchant)
                                .font(.moneBodyLg)
                                .foregroundStyle(Color.monePrimary)
                                .tint(Color.moneActionFill)
                                .padding(MoneSpacing.cardSm)
                                .background(Color.moneSurface)
                                .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                                        .strokeBorder(Color.moneStroke, lineWidth: 1)
                                )
                        }

                        // Amount
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Amount")
                                .font(.moneLabelCaps)
                                .tracking(0.8)
                                .foregroundStyle(Color.moneTertiary)

                            HStack(spacing: 8) {
                                Text("₹")
                                    .font(.moneAmtMd)
                                    .foregroundStyle(Color.moneSecondary)
                                TextField("0", value: Bindable(appVM).payAmount, format: .number)
                                    .font(.moneAmtMd)
                                    .foregroundStyle(Color.monePrimary)
                                    .tint(Color.moneActionFill)
                                    .keyboardType(.decimalPad)
                                    .focused($amountFocused)
                            }
                            .padding(MoneSpacing.cardSm)
                            .background(Color.moneSurface)
                            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous)
                                    .strokeBorder(Color.moneStroke, lineWidth: 1)
                            )
                        }

                        // Category
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.moneLabelCaps)
                                .tracking(0.8)
                                .foregroundStyle(Color.moneTertiary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: MoneSpacing.gap) {
                                    ForEach(
                                        [TransactionCategory.food, .shopping, .transport, .entertainment, .bills, .other],
                                        id: \.rawValue
                                    ) { cat in
                                        FilterChip(
                                            title: cat.rawValue,
                                            isSelected: appVM.payCategory == cat
                                        ) {
                                            appVM.payCategory = cat
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Safe-to-spend context
                    if appVM.payAmount > 0 {
                        PayImpactPreview(amount: appVM.payAmount)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Check impact CTA
                    MonePrimaryButton(
                        title: "Check impact",
                        icon: "shield.lefthalf.filled"
                    ) {
                        amountFocused = false
                        appVM.evaluatePay()
                    }
                    .disabled(appVM.payAmount <= 0)
                    .opacity(appVM.payAmount > 0 ? 1 : 0.4)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, MoneSpacing.page)
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerSheet()
        }
        .sheet(isPresented: Bindable(appVM).showNudge) {
            if let nudge = appVM.activeNudge {
                NudgeSheetView(nudge: nudge)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appVM.payAmount)
    }
}

// MARK: - Pay Impact Preview

struct PayImpactPreview: View {
    @Environment(AppViewModel.self) private var appVM
    let amount: Double

    var impact: PaymentImpact {
        SafeToSpendCalculator.impactOfPayment(
            amount: amount,
            moneyMap: appVM.moneyMap,
            spentThisWeek: appVM.spentThisWeek
        )
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("After this payment")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
                Text(impact.remainingAfterPayment >= 0 ?
                     "₹\(formatted(impact.remainingAfterPayment)) remaining this week" :
                     "₹\(formatted(abs(impact.remainingAfterPayment))) over weekly budget")
                    .font(.moneBodyMd)
                    .foregroundStyle(impact.riskLevel.color)
            }
            Spacer()
            HealthChip(status: impact.riskLevel)
        }
        .padding(MoneSpacing.cardSm)
        .background(impact.riskLevel.bgColor)
        .clipShape(RoundedRectangle(cornerRadius: MoneRadius.lg, style: .continuous))
    }

    private func formatted(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

// MARK: - QR Scanner Sheet (simulated)

struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            VStack(spacing: MoneSpacing.section) {
                // Scanner frame simulation
                ZStack {
                    RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous)
                        .fill(Color.moneSurface)
                        .frame(width: 260, height: 260)
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80, weight: .thin))
                            .foregroundStyle(Color.moneSecondary)
                        Text("Point at a QR code")
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }
                    // Corner marks
                    GeometryReader { geo in
                        let s: CGFloat = 24
                        let w: CGFloat = 2
                        Group {
                            // Top-left
                            Path { p in p.move(to: CGPoint(x: 12, y: 12+s)); p.addLine(to: CGPoint(x: 12, y: 12)); p.addLine(to: CGPoint(x: 12+s, y: 12)) }
                                .stroke(Color.moneActionFill, lineWidth: w)
                            // Top-right
                            Path { p in p.move(to: CGPoint(x: geo.size.width-12-s, y: 12)); p.addLine(to: CGPoint(x: geo.size.width-12, y: 12)); p.addLine(to: CGPoint(x: geo.size.width-12, y: 12+s)) }
                                .stroke(Color.moneActionFill, lineWidth: w)
                            // Bottom-left
                            Path { p in p.move(to: CGPoint(x: 12, y: geo.size.height-12-s)); p.addLine(to: CGPoint(x: 12, y: geo.size.height-12)); p.addLine(to: CGPoint(x: 12+s, y: geo.size.height-12)) }
                                .stroke(Color.moneActionFill, lineWidth: w)
                            // Bottom-right
                            Path { p in p.move(to: CGPoint(x: geo.size.width-12-s, y: geo.size.height-12)); p.addLine(to: CGPoint(x: geo.size.width-12, y: geo.size.height-12)); p.addLine(to: CGPoint(x: geo.size.width-12, y: geo.size.height-12-s)) }
                                .stroke(Color.moneActionFill, lineWidth: w)
                        }
                    }
                }

                Text("Camera access simulated in prototype")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneTertiary)

                // Simulate a detected QR
                MonePrimaryButton(title: "Simulate: Third Wave ₹850") {
                    appVM.payMerchant = "Third Wave Coffee"
                    appVM.payAmount   = 850
                    appVM.payCategory = .food
                    dismiss()
                }
                .padding(.horizontal, MoneSpacing.page)

                MonePrimaryButton(title: "Simulate: Zara ₹8,500") {
                    appVM.payMerchant = "Zara"
                    appVM.payAmount   = 8500
                    appVM.payCategory = .shopping
                    dismiss()
                }
                .padding(.horizontal, MoneSpacing.page)

                MoneSecondaryButton(title: "Cancel") { dismiss() }
                    .padding(.horizontal, MoneSpacing.page)
            }
            .padding(.top, 40)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    PayView()
        .environment(AppViewModel())
}
