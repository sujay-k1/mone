import SwiftUI

struct AgendaEducationView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var showLogin = false

    private let cards: [(agenda: AgendaType, headline: String, detail: String)] = [
        (.controlSpending,
         "Control your\nspending",
         "Know what is safe to spend and get nudges to prevent overspending."),
        (.planGoals,
         "Staying on track\nof your goals",
         "Track your goals and see when spending may push them off track."),
        (.understandPicture,
         "Knowing\nyour money",
         "See your income, cashflow, commitments, and financial health in one place.")
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
                Text("What can moné \nhelp you with?")
                    .font(.moneDisplayMd)
                    .foregroundStyle(Color.monePrimary)
                Text("Swipe through or tap to pick your focus.")
                    .font(.moneBodyLg)
                    .foregroundStyle(Color.moneSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MoneSpacing.page)
            .padding(.top, 24)
            .padding(.bottom, -104)

            SwipeableCardDeck(
                cards: cards,
                primaryAgenda: appVM.primaryAgenda,
                secondaryAgenda: appVM.secondaryAgenda,
                onSelect: handleSelection
            )
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: MoneSpacing.gutter) {
                Button {
                    MoneTactileFeedback.performGentleButtonTap {
                        showLogin = true
                    }
                } label: {
                    Text("Already have an account? Log in")
                        .font(.moneBodyMd)
                        .foregroundStyle(Color.moneTertiary)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)

                if appVM.primaryAgenda != nil {
                    MonePrimaryButton(title: "Continue") {
                        MoneTactileFeedback.performGentleButtonTap {
                            appVM.advance()
                        }
                    }
                }
            }
            .padding(.horizontal, MoneSpacing.page)
            .padding(.bottom, MoneSpacing.gutter)
            .animation(.easeInOut(duration: 0.35), value: appVM.primaryAgenda)
        }
        .background(Color.moneBackground.ignoresSafeArea())
        .sheet(isPresented: $showLogin) {
            LoginRestoreSheet()
        }
    }

    private func handleSelection(_ agenda: AgendaType) {
        if appVM.primaryAgenda == agenda {
            appVM.primaryAgenda = nil
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
    @State private var hintTask: Task<Void, Never>?
    @State private var isHintAnimating = false
    @State private var isTrackingUserDrag = false
    @State private var nextHintDirection: CGFloat = -1

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
                        agenda: cards[i].agenda,
                        headline: cards[i].headline,
                        detail: cards[i].detail,
                        isSelected: sel,
                        isPrimary: pri,
                        showDetail: shouldShowDetail(i, s, cardW, cardH),
                        isFront: s == 0 && !flying[i],
                        cardXOffset: (flying[i] ? fOffset[i] : offset(i, s, cfg)).width
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
                    .allowsHitTesting(!animating && !isHintAnimating)
                    .onTapGesture { handleTap(i, s, cardW) }
                    .simultaneousGesture(makeDrag(i, s, cardW, cardH))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            scheduleHint(after: 0.8)
        }
        .onDisappear {
            cancelHint(resetCard: true)
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

    private func shouldShowDetail(_ i: Int, _ s: Int, _ w: CGFloat, _ h: CGFloat) -> Bool {
        guard !flying[i] else { return false }
        guard s > 0 else { return true }
        return visibleFraction(for: i, slot: s, cardWidth: w, cardHeight: h) >= 0.8
    }

    private func visibleFraction(for i: Int, slot s: Int, cardWidth w: CGFloat, cardHeight h: CGFloat) -> CGFloat {
        let cardRect = rect(for: i, slot: s, cardWidth: w, cardHeight: h)
        let cardArea = cardRect.width * cardRect.height
        guard cardArea > 0 else { return 0 }

        var coveredArea: CGFloat = 0
        for coveringSlot in 0..<s {
            let coveringIndex = cardAt(slot: coveringSlot)
            guard !flying[coveringIndex], fOpacity[coveringIndex] > 0.01 else { continue }
            coveredArea += cardRect.intersection(rect(for: coveringIndex, slot: coveringSlot, cardWidth: w, cardHeight: h)).area
        }

        return max(0, min(1, (cardArea - coveredArea) / cardArea))
    }

    private func rect(for i: Int, slot s: Int, cardWidth w: CGFloat, cardHeight h: CGFloat) -> CGRect {
        let cfg = slots[s]
        let scale = flying[i] ? 1 : cfg.scale
        let size = CGSize(width: w * scale, height: h * scale)
        let center = flying[i] ? fOffset[i] : offset(i, s, cfg)
        return CGRect(
            x: center.width - size.width / 2,
            y: center.height - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    // MARK: Hint Animation

    private func recordUserActivity() {
        cancelHint(resetCard: true)
        scheduleHint(after: 4)
    }

    private func scheduleHint(after delay: TimeInterval) {
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            guard await sleep(seconds: delay) else { return }
            await runHintLoop()
        }
    }

    private func cancelHint(resetCard: Bool) {
        hintTask?.cancel()
        hintTask = nil
        isHintAnimating = false

        guard resetCard else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            dragOffset = .zero
            dragRotation = 0
        }
    }

    @MainActor
    private func runHintLoop() async {
        var direction = nextHintDirection

        while !Task.isCancelled {
            if animating || flying.contains(true) || dragOffset != .zero {
                guard await sleep(seconds: 0.4) else { break }
                continue
            }

            isHintAnimating = true
            MoneTactileFeedback.playCardHintOut()
            withAnimation(.easeOut(duration: 0.55)) {
                dragOffset = CGSize(width: direction * 78, height: 18)
                dragRotation = Double(direction * -4)
            }

            guard await sleep(seconds: 0.55) else { break }

            MoneTactileFeedback.playCardHintReturn()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                dragOffset = .zero
                dragRotation = 0
            }

            guard await sleep(seconds: 0.65) else { break }

            isHintAnimating = false
            direction *= -1
            nextHintDirection = direction

            guard await sleep(seconds: 2) else { break }
        }

        isHintAnimating = false
        dragOffset = .zero
        dragRotation = 0
    }

    private func sleep(seconds: TimeInterval) async -> Bool {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    // MARK: Drag

    private func makeDrag(_ i: Int, _ s: Int, _ w: CGFloat, _ h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard s == 0, !animating, !flying[i] else { return }
                if !isTrackingUserDrag {
                    isTrackingUserDrag = true
                    recordUserActivity()
                }
                let normY = (v.startLocation.y / h - 0.5) * 2
                leverArm = normY
                dragOffset = v.translation
                dragRotation = v.translation.width * (-normY) * 0.04
            }
            .onEnded { v in
                guard s == 0, !animating, !flying[i] else { return }
                isTrackingUserDrag = false
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
        recordUserActivity()
        let wasSelected = primaryAgenda == cards[i].agenda || secondaryAgenda == cards[i].agenda
        if s == 0 {
            onSelect(cards[i].agenda)
        } else {
            let ag = cards[i].agenda
            onSelect(ag)
            autoCycle(steps: s, cardWidth: w)
        }
        MoneTactileFeedback.playSelection(isSelected: !wasSelected)
    }

    // MARK: Manual Swipe Off

    private func swipeOff(_ ci: Int, _ dir: CGFloat, _ velY: CGFloat, _ w: CGFloat) {
        guard !animating else { return }
        animating = true
        MoneTactileFeedback.playCardSwipe()

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

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}

// MARK: - Agenda Stack Card

private struct AgendaStackCard: View {
    let agenda: AgendaType
    let headline: String
    let detail: String
    let isSelected: Bool
    let isPrimary: Bool
    var showDetail: Bool = true
    var isFront: Bool = true
    var cardXOffset: CGFloat = 0

    @State private var showSpendingSlash = false
    @State private var useSpendingSlashDisappear = false
    @State private var showGoalTrackSymbol = false
    @State private var useGoalTrackDisappear = false
    @State private var moneyMagnifierAngle = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Group 1: title + selection tag ───────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.moneHL)
                        .foregroundStyle(Color.monePrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if isSelected {
                        Text(isPrimary ? "PRIMARY" : "SECONDARY")
                            .font(.moneLabelCaps)
                            .tracking(1.5)
                            .foregroundStyle(isPrimary ? Color.moneCelebration : Color.moneSecondary)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

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

            // ── Flexible gap ─────────────────────────────────────────────
            Spacer(minLength: 12)

            // ── Group 2: description + animated icon ─────────────────────
            HStack(alignment: .center, spacing: 14) {
                Text(detail)
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.moneSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                if agenda == .controlSpending {
                    SpendingControlSymbol(
                        showSlash: showSpendingSlash,
                        useDisappearTransition: useSpendingSlashDisappear
                    )
                } else if agenda == .planGoals {
                    GoalTrackSymbol(
                        showSymbol: showGoalTrackSymbol,
                        useDisappearTransition: useGoalTrackDisappear
                    )
                } else if agenda == .understandPicture {
                    MoneyKnowledgeSymbol(
                        isAnimating: isFront,
                        magnifierAngle: moneyMagnifierAngle,
                        cardXOffset: cardXOffset
                    )
                }
            }
            .opacity(showDetail ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: showDetail)
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
        .task(id: agenda == .controlSpending && isFront) {
            guard agenda == .controlSpending, isFront else {
                var resetTransaction = SwiftUI.Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    showSpendingSlash = false
                    useSpendingSlashDisappear = false
                }
                return
            }

            while !Task.isCancelled {
                var resetTransaction = SwiftUI.Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    showSpendingSlash = false
                    useSpendingSlashDisappear = false
                }
                try? await Task.sleep(for: .milliseconds(80))

                withAnimation(.easeInOut(duration: 2.0)) {
                    showSpendingSlash = true
                }
                try? await Task.sleep(for: .seconds(2))

                useSpendingSlashDisappear = true
                withAnimation(.easeOut(duration: 2.0)) {
                    showSpendingSlash = false
                }
                try? await Task.sleep(for: .seconds(2))
                try? await Task.sleep(for: .milliseconds(1_500))
            }
        }
        .task(id: agenda == .planGoals && isFront) {
            guard agenda == .planGoals, isFront else {
                var resetTransaction = SwiftUI.Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    showGoalTrackSymbol = false
                    useGoalTrackDisappear = false
                }
                return
            }

            while !Task.isCancelled {
                var resetTransaction = SwiftUI.Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    showGoalTrackSymbol = false
                    useGoalTrackDisappear = false
                }
                try? await Task.sleep(for: .milliseconds(80))

                withAnimation(.easeInOut(duration: 2.0)) {
                    showGoalTrackSymbol = true
                }
                try? await Task.sleep(for: .seconds(2))

                useGoalTrackDisappear = true
                withAnimation(.easeOut(duration: 2.0)) {
                    showGoalTrackSymbol = false
                }
                try? await Task.sleep(for: .seconds(2))
                try? await Task.sleep(for: .milliseconds(1_500))
            }
        }
        .task(id: agenda == .understandPicture && isFront) {
            guard agenda == .understandPicture, isFront else {
                var resetTransaction = SwiftUI.Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    moneyMagnifierAngle = 0
                }
                return
            }

            moneyMagnifierAngle = 0
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                moneyMagnifierAngle = 360
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct SpendingControlSymbol: View {
    let showSlash: Bool
    let useDisappearTransition: Bool

    var body: some View {
        ZStack {
            Image(systemName: "indianrupeesign")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.moneTertiary)
                .opacity(0.5)
                //.offset(x:24, y:40)

            if showSlash {
                if useDisappearTransition {
                    slashImage
                        .transition(.symbolEffect(.disappear))
                } else {
                    slashImage
                        .transition(.symbolEffect(.drawOn))
                }
            }
        }
        .frame(width: 68, height: 68)
        .accessibilityHidden(true)
    }

    private var slashImage: some View {
        Image(systemName: "circle.slash")
            .font(.system(size: 92, weight: .ultraLight))
            .foregroundStyle(Color.moneTertiary)
            .opacity(0.8)
            //.offset(x:24, y:40)
    }
}

private struct GoalTrackSymbol: View {
    let showSymbol: Bool
    let useDisappearTransition: Bool

    var body: some View {
        ZStack {
            if showSymbol {
                if useDisappearTransition {
                    symbolImage
                        .transition(.symbolEffect(.disappear))
                } else {
                    symbolImage
                        .transition(.symbolEffect(.drawOn))
                }
            }
        }
        .frame(width: 68, height: 68)
        .accessibilityHidden(true)
    }

    private var symbolImage: some View {
        Image(systemName: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(Color.moneTertiary)
            .opacity(0.8)
    }
}

private struct MoneyKnowledgeSymbol: View {
    let isAnimating: Bool
    let magnifierAngle: Double  // kept for API compatibility
    let cardXOffset: CGFloat

    private let orbitRadius: CGFloat = 26
    private let outerSize:   CGFloat = 96
    private let orbitPeriod: Double  = 3.0  // seconds per full revolution
    private let maxCompensatedCardXOffset: CGFloat = 160
    private let glassCardXScaleCompensation: CGFloat = 0.28

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60, paused: !isAnimating)) { context in
            let elapsed  = context.date.timeIntervalSinceReferenceDate
            let radians  = (elapsed.truncatingRemainder(dividingBy: orbitPeriod) / orbitPeriod) * 2 * Double.pi
            // Direct trig: place magnifier at the correct point on the circle each frame.
            let offsetX  = CGFloat(cos(radians)) * orbitRadius
            let offsetY  = CGFloat(sin(radians)) * orbitRadius
            let normalizedCardX = min(max(cardXOffset / maxCompensatedCardXOffset, -1), 1)
            let glassScale = 1 + (normalizedCardX * glassCardXScaleCompensation)

            ZStack {
                // Faint orbit guide ring
                Circle()
                    .stroke(Color.moneTertiary.opacity(0),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(width: orbitRadius * 2, height: orbitRadius * 2)

                // Centre anchor
                Image(systemName: "banknote")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.moneTertiary)
                    .opacity(0.50)
                    .symbolEffect(.pulse, isActive: isAnimating)

                if #available(iOS 26, *) {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 32)
                        .glassEffect(.clear)
                        .scaleEffect(glassScale)
                        .offset(x: offsetX, y: offsetY)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)
                        .scaleEffect(glassScale)
                        .offset(x: offsetX, y: offsetY)
                }

                Rectangle()
                    .fill(Color.moneTertiary.opacity(0.7))
                    .frame(width: 18, height: 2)
                    .rotationEffect(.degrees(45))
                    .offset(x: offsetX+23, y: offsetY+23)

                // Magnifier — positioned on the circle via offset each frame
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Color.moneTertiary)
                    .opacity(0.0)
                    .offset(x: offsetX, y: offsetY)
            }
            .frame(width: outerSize, height: outerSize)
        }
        .accessibilityHidden(true)
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
                    Button("Cancel") {
                        MoneTactileFeedback.performGentleButtonTap {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.monePrimary)
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
