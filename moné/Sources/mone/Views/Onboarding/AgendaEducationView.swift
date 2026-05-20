import SwiftUI

struct AgendaEducationView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var showLogin = false

    private let cards: [(agenda: AgendaType, headline: String, detail: String)] = [
        (.controlSpending,
         "Control my\nspending",
         "Know what is safe to spend and get nudges to prevent overspending."),
        (.planGoals,
         "Stay on track\nof my goals",
         "Track your goals and see when spending may push them off track."),
        (.understandPicture,
         "Knowing\nmy money",
         "See your income, commitments, cashflow, and financial health in one place.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("mon\u{00E9}")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color.monePrimary)
                Spacer()
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("What matters\nmost to you?")
                    .font(.moneDisplayMd)
                    .foregroundStyle(Color.monePrimary)
                Text("Swipe through or tap to pick your focus.")
                    .font(.moneBodyLg)
                    .foregroundStyle(Color.moneSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, 24)

            SwipeableCardDeck(
                cards: cards,
                primaryAgenda: appVM.primaryAgenda,
                secondaryAgenda: appVM.secondaryAgenda,
                onSelect: handleSelection
            )

            Spacer(minLength: MoneSpacing.gutter)

            VStack(spacing: MoneSpacing.gutter) {
                Button {
                    showLogin = true
                } label: {
                    Text("Already have an account? Log in")
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneTertiary)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)
                
                if appVM.primaryAgenda != nil {
                    MonePrimaryButton(title: "Continue") {
                        appVM.advance()
                    }
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.bottom, 0)
            .animation(.easeInOut(duration: 0.35), value: appVM.primaryAgenda)
        }
        .background(Color.moneBackground.ignoresSafeArea())
        .sheet(isPresented: $showLogin) {
            LoginRestoreSheet()
        }
    }

    private func handleSelection(_ agenda: AgendaType) {
        if appVM.primaryAgenda == agenda {
            appVM.selectPrimary(agenda)
            appVM.selectSecondary(nil)
            return
        }
        if appVM.secondaryAgenda == agenda {
            appVM.selectSecondary(nil)
            return
        }
        if appVM.primaryAgenda == nil {
            appVM.selectPrimary(agenda)
        } else if appVM.secondaryAgenda == nil {
            appVM.selectSecondary(agenda)
        } else {
            appVM.selectSecondary(agenda)
        }
    }
}

// MARK: - Swipeable Card Deck

private struct SwipeableCardDeck: View {
    let cards: [(agenda: AgendaType, headline: String, detail: String)]
    let primaryAgenda: AgendaType?
    let secondaryAgenda: AgendaType?
    let onSelect: (AgendaType) -> Void

    private let count: Int

    @State private var frontIndex: Int = 0
    @State private var animating = false

    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0
    @State private var leverArm: CGFloat = 0

    @State private var flying: [Bool]
    @State private var fOffset: [CGSize]
    @State private var fRotation: [Double]
    @State private var fOpacity: [Double]

    private struct Slot {
        let offset: CGSize
        let rotation: Double
        let scale: CGFloat
        let shadow: CGFloat
    }

    private let slots = [
        Slot(offset: CGSize(width: 0, height: 132), rotation: 6, scale: 1.0, shadow: 12),
        Slot(offset: CGSize(width: 0, height: -8), rotation: -2, scale: 0.96, shadow: 8),
        Slot(offset: CGSize(width: -10, height: -142), rotation: -10, scale: 0.92, shadow: 4),
    ]

    init(
        cards: [(agenda: AgendaType, headline: String, detail: String)],
        primaryAgenda: AgendaType?,
        secondaryAgenda: AgendaType?,
        onSelect: @escaping (AgendaType) -> Void
    ) {
        self.cards = cards
        self.primaryAgenda = primaryAgenda
        self.secondaryAgenda = secondaryAgenda
        self.onSelect = onSelect
        self.count = cards.count
        _flying = State(initialValue: .init(repeating: false, count: cards.count))
        _fOffset = State(initialValue: .init(repeating: .zero, count: cards.count))
        _fRotation = State(initialValue: .init(repeating: 0, count: cards.count))
        _fOpacity = State(initialValue: .init(repeating: 1, count: cards.count))
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = min(geo.size.width * 0.9, 350)
            let cardH = min(cardW * 0.6, geo.size.height * 0.88)

            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let s = slotOf(i)
                    let cfg = slots[s]
                    let ag = cards[i].agenda
                    let sel = primaryAgenda == ag || secondaryAgenda == ag
                    let pri = primaryAgenda == ag

                    AgendaStackCard(
                        headline: cards[i].headline,
                        detail: cards[i].detail,
                        isSelected: sel,
                        isPrimary: pri,
                        showDetail: s == 0 && !flying[i]
                    )
                    .frame(width: cardW, height: cardH)
                    .scaleEffect(flying[i] ? 1 : cfg.scale)
                    .rotationEffect(.degrees(flying[i] ? fRotation[i] : rotation(i, s, cfg)))
                    .offset(flying[i] ? fOffset[i] : offset(i, s, cfg))
                    .shadow(
                        color: .black.opacity(flying[i] ? 0.15 : (s == 0 ? 0.18 : 0.08)),
                        radius: flying[i] ? 10 : cfg.shadow,
                        y: 4
                    )
                    .opacity(fOpacity[i])
                    .zIndex(flying[i] ? 10 : Double(count - s))
                    .allowsHitTesting(!animating)
                    .onTapGesture { handleTap(i, s, cardW) }
                    .simultaneousGesture(makeDrag(i, s, cardW, cardH))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Slot Math

    private func slotOf(_ i: Int) -> Int {
        (i - frontIndex + count) % count
    }

    private func cardAt(slot s: Int) -> Int {
        (frontIndex + s) % count
    }

    private func offset(_ i: Int, _ s: Int, _ cfg: Slot) -> CGSize {
        guard s == 0 else { return cfg.offset }
        return CGSize(
            width: cfg.offset.width + dragOffset.width,
            height: cfg.offset.height + dragOffset.height
        )
    }

    private func rotation(_ i: Int, _ s: Int, _ cfg: Slot) -> Double {
        guard s == 0 else { return cfg.rotation }
        return cfg.rotation + dragRotation
    }

    // MARK: Drag

    private func makeDrag(_ i: Int, _ s: Int, _ w: CGFloat, _ h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard s == 0, !animating, !flying[i] else { return }
                let normY = (v.startLocation.y / h - 0.5) * 2
                leverArm = normY
                dragOffset = v.translation
                dragRotation = v.translation.width * (-normY) * 0.04
            }
            .onEnded { v in
                guard s == 0, !animating, !flying[i] else { return }
                let vel = v.predictedEndTranslation.width - v.translation.width
                if abs(vel) > 120 || abs(v.translation.width) > 90 {
                    let dir: CGFloat = v.translation.width >= 0 ? 1 : -1
                    let velY = v.predictedEndTranslation.height - v.translation.height
                    swipeOff(i, dir, velY, w)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = .zero
                        dragRotation = 0
                    }
                }
            }
    }

    // MARK: Tap

    private func handleTap(_ i: Int, _ s: Int, _ w: CGFloat) {
        guard !animating else { return }
        if s == 0 {
            onSelect(cards[i].agenda)
        } else {
            let ag = cards[i].agenda
            if primaryAgenda != ag && secondaryAgenda != ag {
                onSelect(ag)
            }
            autoCycle(steps: s, cardWidth: w)
        }
    }

    // MARK: Manual Swipe Off

    private func swipeOff(_ ci: Int, _ dir: CGFloat, _ velY: CGFloat, _ w: CGFloat) {
        guard !animating else { return }
        animating = true

        let screen = UIScreen.main.bounds.width
        let exitX = dir * (screen + w)
        let exitY = velY * 0.15
        let curRot = slots[0].rotation + dragRotation
        let exitRot = curRot + dir * (-leverArm) * 18 + dir * 10

        fOffset[ci] = CGSize(
            width: slots[0].offset.width + dragOffset.width,
            height: slots[0].offset.height + dragOffset.height
        )
        fRotation[ci] = curRot
        flying[ci] = true

        dragOffset = .zero
        dragRotation = 0
        leverArm = 0

        withAnimation(.easeOut(duration: 0.5)) {
            fOffset[ci] = CGSize(width: exitX, height: exitY)
            fRotation[ci] = exitRot
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.08)) {
            fOpacity[ci] = 0
        }

        after(0.15) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                frontIndex = (frontIndex + 1) % count
            }
        }
        after(0.55) { revive(ci) }
    }

    // MARK: Auto Cycle

    private func autoCycle(steps: Int, cardWidth w: CGFloat) {
        guard !animating, steps > 0 else { return }
        animating = true

        let screen = UIScreen.main.bounds.width

        for step in 0..<steps {
            let ci = cardAt(slot: step)
            let cfg = slots[step]
            let dir: CGFloat = step.isMultiple(of: 2) ? -1 : 1
            let delay = Double(step) * 0.08

            fOffset[ci] = cfg.offset
            fRotation[ci] = cfg.rotation
            flying[ci] = true

            after(delay) {
                withAnimation(.easeOut(duration: 0.45)) {
                    fOffset[ci] = CGSize(width: dir * (screen + w), height: dir * -15)
                    fRotation[ci] = cfg.rotation + dir * 22
                }
                withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
                    fOpacity[ci] = 0
                }
            }
        }

        after(0.18) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                frontIndex = (frontIndex + steps) % count
            }
        }

        let total = Double(steps - 1) * 0.08 + 0.55
        after(total) {
            for i in 0..<count where flying[i] { revive(i) }
        }
    }

    // MARK: Revive

    private func revive(_ ci: Int) {
        var t = SwiftUI.Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            flying[ci] = false
            fOffset[ci] = .zero
            fRotation[ci] = 0
        }
        withAnimation(.easeIn(duration: 0.3)) {
            fOpacity[ci] = 1
        }
        after(0.35) {
            if !flying.contains(true) { animating = false }
        }
    }

    private func after(_ s: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: action)
    }
}

// MARK: - Agenda Stack Card

private struct AgendaStackCard: View {
    let headline: String
    let detail: String
    let isSelected: Bool
    let isPrimary: Bool
    var showDetail: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.moneHL)
                        .foregroundStyle(Color.monePrimary)

                    if isSelected {
                        Text(isPrimary ? "PRIMARY" : "SECONDARY")
                            .font(.moneLabelCaps)
                            .tracking(1.5)
                            .foregroundStyle(isPrimary ? Color.moneCelebration : Color.moneSecondary)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.clear : Color.moneStrokeMid,
                            lineWidth: 1.5
                        )
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(isPrimary ? Color.moneCelebration : Color.moneSecondary)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }

            Spacer()

            Text(detail)
                .font(.moneBodyMd)
                .foregroundStyle(Color.moneSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showDetail ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showDetail)
                .padding(.bottom, 24)
        }
        .padding(MoneSpacing.cardLg)
        .background(
            RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous)
                .fill(isSelected ? Color.moneSurfaceEl : Color.moneSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.moneStrokeBright : Color.moneStroke,
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: MoneRadius.xxl, style: .continuous))
    }
}

// MARK: - Login/Restore Sheet

private struct LoginRestoreSheet: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AuthView(
                onAuthComplete: {
                    Task {
                        await sessionVM.handleAuthSuccess()
                        dismiss()
                    }
                },
                showBackButton: false
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.moneTertiary)
                }
            }
        }
    }
}
#Preview {
    AgendaEducationView()
        .environment(AppViewModel())
        .environment(SessionViewModel())
}
