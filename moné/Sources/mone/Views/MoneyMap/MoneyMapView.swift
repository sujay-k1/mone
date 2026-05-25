import SwiftUI
import SwiftData
import Charts

struct MoneyMapView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var modelContext

    @State private var model: MoneyMapScreenModel?
    @State private var errorMessage: String?
    @State private var showTransactionHistory = false
    @State private var transactionHistoryFilter: MoneyMapTransactionFilter = .all
    @State private var shouldRunTourAutoScroll = false

    // ── Card expand state ────────────────────────────────────────────────
    @State private var expandedItem: MoneyMapItem? = nil
    @State private var expandedGroup: MoneyMapCategoryGroup? = nil
    @State private var expandedSubscriptions: Bool = false
    @State private var cardDragOffset: CGFloat = 0

    // Directly-animatable overlay geometry — no computed intermediaries.
    // We set these to the source frame on tap (no animation), then
    // DispatchQueue.main.async to animate to the expanded values, guaranteeing
    // two separate render passes.
    @State private var overlayCenter: CGPoint = .zero
    @State private var overlaySize: CGSize = .zero
    @State private var scrimVisible: Bool = false
    @State private var expandedSourceFrame: CGRect = .zero
    @State private var dismissToken: UUID = UUID()

    // Card frame tracking
    @State private var cardFrames: [String: CGRect] = [:]

    private struct CardFrameKey: PreferenceKey {
        static var defaultValue: [String: CGRect] = [:]
        static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
            value.merge(nextValue()) { $1 }
        }
    }

    // Container geometry is read by a root GeometryReader (more reliable than .background).
    @State private var containerSize: CGSize = .zero

    private var containerCenter: CGPoint {
        CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
    }
    private var expandedSideLength: CGFloat {
        max(containerSize.width - MoneSpacing.page * 2, 0)
    }
    private var isShowingOverlay: Bool {
        expandedItem != nil || expandedGroup != nil || expandedSubscriptions
    }
    private enum TourScrollTarget {
        static let top = "moneyMapTourTop"
        static let lower = "moneyMapTourLower"
        static let bottom = "moneyMapTourBottom"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.moneBackground.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 36) {
                            if let model {
                                header(model)
                                    .id(TourScrollTarget.top)
                                snapshotCard(model)
                                committedSection(model)
                                everydaySection(model)
                                    .id(TourScrollTarget.lower)
                                outliersSection(model)
                                fundSection(model)
                                liabilitiesSection(model)
                                reviewSection(model)
                            } else if let errorMessage {
                                errorState(errorMessage)
                            } else {
                                loadingState
                            }
                            Spacer(minLength: 28)
                                .id(TourScrollTarget.bottom)
                        }
                        .padding(.horizontal, MoneSpacing.page)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .moneTabTourStepDidChange)) { notification in
                        guard notification.userInfo?["step"] as? String == MoneTabTourStepName.moneyMap else { return }
                        shouldRunTourAutoScroll = true
                        runTourAutoScrollIfReady(proxy)
                    }
                    .onAppear {
                        if UserDefaults.standard.string(forKey: MoneTabTourStepName.activeStepDefaultsKey) == MoneTabTourStepName.moneyMap {
                            shouldRunTourAutoScroll = true
                            runTourAutoScrollIfReady(proxy)
                        }
                    }
                    .onChange(of: model != nil) { _, _ in
                        runTourAutoScrollIfReady(proxy)
                    }
                }

                // ── Scrim ────────────────────────────────────────────────
                if isShowingOverlay {
                    Color.black
                        .opacity(scrimVisible ? 0.55 * Double(1 - min(cardDragOffset / 300, 1)) : 0)
                        .ignoresSafeArea()
                        .onTapGesture { dismissToSource() }
                        .animation(.easeInOut(duration: 0.25), value: scrimVisible)
                        .animation(.easeInOut(duration: 0.1), value: cardDragOffset)
                        .zIndex(10)
                }

                // ── Overlay card ─────────────────────────────────────────
                if let item = expandedItem {
                    overlayCard { MoneyMapMiniCard(item: item, isExpanded: true) }.zIndex(11)
                } else if let group = expandedGroup {
                    overlayCard { MoneyMapCategoryCard(group: group, isExpanded: true) }.zIndex(11)
                } else if expandedSubscriptions, let m = model {
                    overlayCard { SubscriptionsMiniCard(items: m.subscriptionItems, isExpanded: true) }.zIndex(11)
                }
            }
            .coordinateSpace(name: "moneyMapRoot")
            .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }
            .onAppear { containerSize = geo.size }
            .onChange(of: geo.size) { _, s in containerSize = s }
        }
        .task { loadMoneyMap() }
        .sheet(isPresented: $showTransactionHistory, onDismiss: {
            appVM.moneyMapDeepLink = nil
        }) {
            if let model {
                MoneyMapTransactionHistorySheet(
                    model: model,
                    initialFilter: transactionHistoryFilter,
                    onRetag: { transaction, option in retag(transaction, as: option) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.moneBackground)
            }
        }
        .onChange(of: appVM.moneyMapDeepLink) { _, deepLink in handleDeepLink(deepLink) }
        .onAppear { handleDeepLink(appVM.moneyMapDeepLink) }
    }

    private func runTourAutoScrollIfReady(_ proxy: ScrollViewProxy) {
        guard shouldRunTourAutoScroll, model != nil else { return }
        shouldRunTourAutoScroll = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.linear(duration: 48.0)) {
                proxy.scrollTo(TourScrollTarget.bottom, anchor: .bottom)
            }
        }
    }

    // ── Expand / dismiss ─────────────────────────────────────────────────

    private func expand(frameKey: String, action: () -> Void) {
        let src = cardFrames[frameKey] ?? CGRect(origin: containerCenter, size: .zero)
        expandedSourceFrame = src
        MoneTactileFeedback.playElasticCardExpand()

        // Step 1 — place overlay at source frame, no animation
        overlayCenter = CGPoint(x: src.midX, y: src.midY)
        overlaySize   = CGSize(width: src.width, height: src.height)
        scrimVisible  = false
        action()   // inserts the overlay into the hierarchy

        // Step 2 — next run loop: spring to expanded position
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
                self.overlayCenter = self.containerCenter
                self.overlaySize = CGSize(width: self.expandedSideLength, height: self.expandedSideLength)
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.scrimVisible = true
            }
        }
    }

    private func dismissToSource() {
        let token = UUID()
        dismissToken = token
        MoneTactileFeedback.playDampedCardCollapse()
        withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
            overlayCenter = CGPoint(x: expandedSourceFrame.midX, y: expandedSourceFrame.midY)
            overlaySize   = CGSize(width: expandedSourceFrame.width,
                                   height: expandedSourceFrame.height)
            cardDragOffset = 0
        }
        withAnimation(.easeInOut(duration: 0.2)) { scrimVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard self.dismissToken == token else { return }
            self.expandedItem = nil
            self.expandedGroup = nil
            self.expandedSubscriptions = false
        }
    }

    private var expandDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 { cardDragOffset = value.translation.height }
            }
            .onEnded { value in
                if value.translation.height > 100 || value.predictedEndTranslation.height > 300 {
                    dismissToSource()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { cardDragOffset = 0 }
                }
            }
    }

    // ── Overlay card ─────────────────────────────────────────────────────

    @ViewBuilder
    private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: overlaySize.width, height: overlaySize.height)
            .clipShape(RoundedRectangle(cornerRadius: MoneRadius.xl, style: .continuous))
            .position(overlayCenter)
            .offset(y: cardDragOffset)
            .gesture(expandDragGesture)
            .animation(.spring(response: 0.45, dampingFraction: 0.80), value: overlaySize.width)
            .animation(.spring(response: 0.45, dampingFraction: 0.80), value: overlayCenter)
    }

    // ── Frame reporter ────────────────────────────────────────────────────

    private func frameReporter(key: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: CardFrameKey.self,
                value: [key: geo.frame(in: .named("moneyMapRoot"))]
            )
        }
    }

    // ── Deeplink ──────────────────────────────────────────────────────────

    private func handleDeepLink(_ deepLink: AppViewModel.MoneyMapDeepLink?) {
        guard let deepLink, model != nil else { return }
        switch deepLink {
        case .openReviewTransactions:
            transactionHistoryFilter = .review
            showTransactionHistory = true
        case .openSubscriptionCard:
            expand(frameKey: "subscriptions") { expandedSubscriptions = true }
        }
    }


    private func header(_ model: MoneyMapScreenModel) -> some View {
        DashboardHeader(
            title: "Money Map",
            subtitle: sessionVM.isSignedIn ? sessionVM.displayName.capitalized : nil,
            tag: formattedMonth(model.month)
        )
    }

    private func formattedMonth(_ monthKey: String) -> String {
        guard monthKey.count == 7,
              let month = Int(monthKey.suffix(2)),
              let year = Int(monthKey.prefix(4)),
              month >= 1 && month <= 12 else { return monthKey }
        let names = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
        return "\(names[month - 1]) \(year)"
    }

    private func snapshotCard(_ model: MoneyMapScreenModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            // ── Income + Confidence ──────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INFLOW VS. OUTFLOW")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneTertiary)

                    Text(formatCurrencyCompact(model.income))
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .foregroundStyle(Color.monePrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(confidenceColor(model.confidence))
                            .frame(width: 7, height: 7)
                        Text("\(model.confidence)% confidence")
                            .font(.moneLabelCaps)
                            .foregroundStyle(confidenceColor(model.confidence))
                    }

                    Text("Refined over \(model.transactionCount) signals")
                        .font(.moneBodySm)
                        .italic()
                        .foregroundStyle(Color.moneSecondary)
                }
            }

            // ── Income vs outflow comparison bars ────────────────────────
            MoneyMapInflowOutflowBars(model: model)

            // ── Bucket index ─────────────────────────────────────────────
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 16
            ) {
                moneyLabel("Committed",   model.regularCommitted + model.subscriptions, .committed)
                moneyLabel("Everyday",    model.everyday,                               .everyday)
                moneyLabel("Investments", model.fund,                                   .fund)
                moneyLabel("Liabilities", model.liability,                              .liability)
                moneyLabel("Tax",         model.taxDeduction,                           .tax)
                moneyLabel("Outliers",    model.outliers,                               .outliers)
                if model.review > 0 {
                    moneyLabel("Review",  model.review,                                 .review)
                }
                moneyLabel(model.operatingRemaining >= 0 ? "Remaining" : "Shortfall",
                           model.operatingRemaining,
                           model.operatingRemaining >= 0 ? .operatingRemaining : .outliers)
            }

            Divider()
                .background(Color.moneStroke)

            // ── Outstanding position ─────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outstanding position")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneTertiary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatCurrencyCompact(model.outstandingLiabilities > 0 ? model.outstandingLiabilities : abs(model.operatingRemaining)))
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .foregroundStyle(model.operatingRemaining < 0 ? Color.moneRisk : Color.monePrimary)

                        Text(model.outstandingLiabilities > 0 ? "Liabilities" : (model.operatingRemaining < 0 ? "Shortfall" : "Surplus"))
                            .font(.moneBodySm)
                            .foregroundStyle(Color.moneSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(model.confidence)%")
                        .font(.moneAmtSm)
                        .foregroundStyle(confidenceColor(model.confidence))

                    Text("Confidence")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneTertiary)
                }
            }

            HStack {
                Text("\(model.transactionCount) items confirmed")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)

                Spacer()

                Text(model.statusLabel.uppercased())
                    .font(.moneLabelCaps)
                    .foregroundStyle(model.operatingRemaining < 0 ? Color.moneRisk : Color.moneSecondary)
            }

            Divider()
                .background(Color.moneStroke)

            MoneSecondaryButton(title: "View transactions", fullWidth: true) {
                showTransactionHistory = true
            }
        }
        .padding(MoneSpacing.cardSm)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    private func moneyLabel(
        _ title: String,
        _ amount: Double,
        _ kind: MoneyMapBucketKind
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(color(for: kind))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneTertiary)

                Text(formatCurrency(amount))
                    .font(.moneAmtSm)
                    .foregroundStyle(Color.monePrimary)
            }
        }
        .frame(minHeight: 42, alignment: .leading)
    }

    private func committedSection(_ model: MoneyMapScreenModel) -> some View {
        let totalCommitted = model.regularCommitted
            + model.liability
            + model.subscriptionItems.map(\.amount).reduce(0, +)
        let hasContent = !model.committedItems.isEmpty
            || !model.subscriptionItems.isEmpty
            || !model.liabilityItems.isEmpty
        return section(
            title: "Monthly committed",
            trailing: "\(formatCurrency(totalCommitted)) detected"
        ) {
            if !hasContent {
                emptySection("No recurring commitments detected for this month.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(model.committedItems) { item in
                        MoneyMapMiniCard(item: item)
                            .background(frameReporter(key: item.id))
                            .opacity(expandedItem?.id == item.id ? 0 : 1)
                            .onTapGesture {
                                expand(frameKey: item.id) { expandedItem = item }
                            }
                    }
                    ForEach(model.liabilityItems) { item in
                        MoneyMapMiniCard(item: item)
                            .background(frameReporter(key: item.id))
                            .opacity(expandedItem?.id == item.id ? 0 : 1)
                            .onTapGesture {
                                expand(frameKey: item.id) { expandedItem = item }
                            }
                    }
                    if !model.subscriptionItems.isEmpty {
                        SubscriptionsMiniCard(items: model.subscriptionItems)
                            .background(frameReporter(key: "subscriptions"))
                            .opacity(expandedSubscriptions ? 0 : 1)
                            .onTapGesture {
                                expand(frameKey: "subscriptions") { expandedSubscriptions = true }
                            }
                    }
                }
            }
        }
    }

    private func everydaySection(_ model: MoneyMapScreenModel) -> some View {
        section(
            title: "Everyday spends",
            trailing: "\(formatCurrency(model.everyday)) tracked"
        ) {
            if model.everydayGroups.isEmpty {
                emptySection("No everyday spend categories detected for this month.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(model.everydayGroups) { group in
                        MoneyMapCategoryCard(group: group)
                            .background(frameReporter(key: group.id))
                            .opacity(expandedGroup?.id == group.id ? 0 : 1)
                            .onTapGesture {
                                expand(frameKey: group.id) { expandedGroup = group }
                            }
                    }
                }
            }
        }
    }

    private func outliersSection(_ model: MoneyMapScreenModel) -> some View {
        section(
            title: "Outliers",
            trailing: "\(formatCurrency(model.outlierItems.map(\.amount).reduce(0, +))) unusual"
        ) {
            if model.outlierItems.isEmpty {
                emptySection("No high-impact unusual items detected from transaction-level data.")
            } else {
                VStack(spacing: 10) {
                    ForEach(model.outlierItems) { item in
                        MoneyMapListRow(item: item)
                    }
                }
            }
        }
    }

    private func fundSection(_ model: MoneyMapScreenModel) -> some View {
        section(
            title: "Fund building",
            trailing: "\(formatCurrency(model.fund)) set aside"
        ) {
            if model.fundItems.isEmpty {
                emptySection("No fund-building transactions detected for this month.")
            } else {
                VStack(spacing: 10) {
                    ForEach(model.fundItems) { item in
                        MoneyMapListRow(item: item)
                    }
                }
            }
        }
    }

    private func liabilitiesSection(_ model: MoneyMapScreenModel) -> some View {
        section(
            title: "Liabilities",
            trailing: model.outstandingLiabilities > 0 ? "\(formatCurrency(model.outstandingLiabilities)) total" : "\(formatCurrency(model.liability)) this month"
        ) {
            if model.liabilityItems.isEmpty {
                emptySection("No liability payments detected for this month.")
            } else {
                VStack(spacing: 10) {
                    ForEach(model.liabilityItems) { item in
                        MoneyMapListRow(item: item)
                    }
                }
            }
        }
    }

    private func reviewSection(_ model: MoneyMapScreenModel) -> some View {
        section(
            title: "Needs review",
            trailing: "\(model.reviewCount) items"
        ) {
            if model.reviewItems.isEmpty {
                emptySection("No review items remain for this month.")
            } else {
                VStack(spacing: 10) {
                    ForEach(model.reviewItems) { item in
                        MoneyMapListRow(item: item)
                    }
                }
            }
        }
        .padding(MoneSpacing.cardSm)
        .background(Color.moneRisk.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func section<Content: View>(
        title: String,
        trailing: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text(title.uppercased())
                    .font(.moneLabelCaps)
                    .tracking(2.5)
                    .foregroundStyle(Color.monePrimary)

                Spacer()

                Text(trailing)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }

            content()
        }
    }

    private func emptySection(_ message: String) -> some View {
        Text(message)
            .font(.moneBodySm)
            .foregroundStyle(Color.moneSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MoneSpacing.cardSm)
            .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.monePrimary)

            Text("Loading Money Map")
                .font(.moneBodyMd)
                .foregroundStyle(Color.moneSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Money Map not ready")
                .font(.moneHLMd)
                .foregroundStyle(Color.monePrimary)

            Text(message)
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .padding(MoneSpacing.cardSm)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    @MainActor
    private func loadMoneyMap() {
        do {
            let loader = MoneyMapDataLoader(modelContext: modelContext)
            model = try loader.loadLatestMoneyMap()

            if model == nil {
                errorMessage = "No processed financial data found. Complete Account Aggregator setup first."
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    @MainActor
    private func retag(
        _ transaction: MoneyMapTransaction,
        as option: MoneyMapRetagOption
    ) {
        do {
            let loader = MoneyMapDataLoader(modelContext: modelContext)
            try loader.retagTransaction(
                transactionId: transaction.id,
                option: option
            )
            model = try loader.loadLatestMoneyMap()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func confidenceColor(_ confidence: Int) -> Color {
        if confidence >= 80 { return Color.moneHealthy }
        if confidence >= 60 { return .orange }
        return Color.moneRisk
    }

    private func color(for kind: MoneyMapBucketKind) -> Color {
        switch kind {
        case .committed:
            return Color.monePrimary
        case .everyday:
            return Color.moneSecondary
        case .fund:
            return Color.moneHealthy
        case .liability:
            return .blue
        case .tax:
            return .purple
        case .outliers:
            return Color.moneRisk.opacity(0.75)
        case .review:
            return .orange
        case .operatingRemaining:
            return Color.moneTertiary.opacity(0.35)
        case .liquidCashImpact:
            return Color.moneRisk
        case .income:
            return Color.moneHealthy
        case .cash:
            return Color.moneSecondary
        case .neutral:
            return Color.moneStroke
        }
    }
}

private struct MoneyMapTransactionHistorySheet: View {
    let model: MoneyMapScreenModel
    var initialFilter: MoneyMapTransactionFilter = .all
    let onRetag: (MoneyMapTransaction, MoneyMapRetagOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: MoneyMapTransactionFilter = .all

    init(model: MoneyMapScreenModel, initialFilter: MoneyMapTransactionFilter = .all, onRetag: @escaping (MoneyMapTransaction, MoneyMapRetagOption) -> Void) {
        self.model = model
        self.initialFilter = initialFilter
        self.onRetag = onRetag
        self._selectedFilter = State(initialValue: initialFilter)
    }

    private var availableFilters: [MoneyMapTransactionFilter] {
        MoneyMapTransactionFilter.allCases.filter { filter in
            filter == .all || model.transactions.contains { filter.matches($0) }
        }
    }

    private var filteredTransactions: [MoneyMapTransaction] {
        model.transactions.filter { selectedFilter.matches($0) }
    }

    private var monthGroups: [MoneyMapTransactionMonthGroup] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            transaction.month
        }

        return grouped
            .map { month, transactions in
                MoneyMapTransactionMonthGroup(
                    month: month,
                    title: monthTitle(month),
                    transactions: transactions.sorted { $0.sortDateText > $1.sortDateText }
                )
            }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            filterBar

            if filteredTransactions.isEmpty {
                emptyTransactions
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                        ForEach(monthGroups) { group in
                            SwiftUI.Section {
                                ForEach(group.transactions) { transaction in
                                    MoneyMapTransactionCard(
                                        transaction: transaction,
                                        onRetag: { option in
                                            onRetag(transaction, option)
                                        }
                                    )
                                }
                            } header: {
                                MoneyMapStickyMonthHeader(group: group)
                            }
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.moneBackground.ignoresSafeArea())
    }

    private var sheetHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transaction history")
                    .font(.moneHLMd)
                    .foregroundStyle(Color.monePrimary)

                Text("\(model.displayName.capitalized) · \(model.transactions.count) transactions")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.moneTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MoneSpacing.page)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters) { filter in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title.uppercased())
                            .font(.moneLabelCaps)
                            .foregroundStyle(selectedFilter == filter ? Color.moneBackground : Color.monePrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.monePrimary : Color.moneStroke.opacity(0.35))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MoneSpacing.page)
        }
        .padding(.bottom, 12)
    }

    private var emptyTransactions: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(Color.moneTertiary)

            Text("No transactions in this filter")
                .font(.moneBodyMd)
                .foregroundStyle(Color.monePrimary)

            Text("Try another category chip.")
                .font(.moneBodySm)
                .foregroundStyle(Color.moneSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(MoneSpacing.page)
    }

    private func monthTitle(_ month: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        guard let date = formatter.date(from: month) else {
            return month
        }

        let output = DateFormatter()
        output.dateFormat = "MMMM yyyy"
        return output.string(from: date)
    }
}

private struct MoneyMapStickyMonthHeader: View {
    let group: MoneyMapTransactionMonthGroup

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(group.title.uppercased())
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.monePrimary)

                Spacer()

                Text("Out \(formatCurrency(group.totalDebits)) · In \(formatCurrency(group.totalCredits))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.moneSecondary)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(Color.moneStroke)
                .frame(height: 0.5)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.moneBackground)
    }
}

private struct MoneyMapTransactionCard: View {
    let transaction: MoneyMapTransaction
    let onRetag: (MoneyMapRetagOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: transaction.symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                    .frame(width: 34, height: 34)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.title)
                        .font(.moneBodyMd)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.monePrimary)
                        .lineLimit(2)

                    Text(transaction.narration)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.moneTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text((transaction.isCredit ? "+" : "−") + formatCurrency(transaction.amount))
                        .font(.moneAmtSm)
                        .foregroundStyle(transaction.isCredit ? Color.moneHealthy : Color.monePrimary)
                        .lineLimit(1)

                    Text(transaction.dateText)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.moneTertiary)
                }
            }

            HStack(spacing: 8) {
                transactionBadge(transaction.mode)
                transactionBadge(displayFamily(transaction.categoryFamily))
                transactionBadge("\(transaction.confidence)%")

                if transaction.needsReview {
                    transactionBadge("Review", color: .orange)
                }
            }

            if let reason = transaction.reviewReason, !reason.isEmpty {
                Text(reason)
                    .font(.moneBodySm)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text(transaction.type.uppercased())
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneTertiary)

                Spacer()

                Menu {
                    ForEach(MoneyMapRetagOption.defaults) { option in
                        Button {
                            onRetag(option)
                        } label: {
                            Label(option.title, systemImage: option.symbolName)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                        Text("Retag")
                    }
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.monePrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.moneStroke.opacity(0.35))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    private var iconColor: Color {
        if transaction.isCredit { return Color.moneHealthy }
        if transaction.needsReview { return .orange }

        switch transaction.kind {
        case .tax, .outliers:
            return Color.moneRisk
        case .fund:
            return Color.moneHealthy
        case .liability:
            return .blue
        default:
            return Color.moneSecondary
        }
    }

    private func transactionBadge(_ text: String, color: Color = Color.moneSecondary) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private func displayFamily(_ family: String) -> String {
        family
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

// MARK: - Diagonal Hatch Fill

private struct DiagonalHatch: View {
    var spacing: CGFloat = 7
    var lineWidth: CGFloat = 0.5
    var color: Color = Color.monePrimary.opacity(0.3)

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            // Draw lines at 45° across the full rect, stepping by `spacing`
            var offset = -size.height
            while offset < size.width {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                offset += spacing
            }
            ctx.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

// MARK: - Inflow vs Outflow Comparison Bars

private struct MoneyMapInflowOutflowBars: View {
    let model: MoneyMapScreenModel

    private var segments: [(label: String, amount: Double, kind: MoneyMapBucketKind)] {
        var s: [(String, Double, MoneyMapBucketKind)] = []
        if model.regularCommitted > 0 { s.append(("Committed",     model.regularCommitted, .committed)) }
        if model.subscriptions    > 0 { s.append(("Subscriptions", model.subscriptions,    .committed)) }
        if model.everyday         > 0 { s.append(("Everyday",      model.everyday,         .everyday))  }
        if model.fund             > 0 { s.append(("Investments",   model.fund,             .fund))      }
        if model.liability        > 0 { s.append(("Liabilities",   model.liability,        .liability)) }
        if model.taxDeduction     > 0 { s.append(("Tax",           model.taxDeduction,     .tax))       }
        if model.outliers         > 0 { s.append(("Outliers",      model.outliers,         .outliers))  }
        if model.review           > 0 { s.append(("Review",        model.review,           .review))    }
        return s
    }

    private var totalOutflow: Double { segments.map(\.amount).reduce(0, +) }

    private let barHeight: CGFloat = 36

    var body: some View {
        let reference = max(model.income, totalOutflow, 1)

        VStack(alignment: .leading, spacing: 4) {
            // ── Inflow label + amount ─────────────────────────────────────
            HStack {
                Text("INFLOW")
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneTertiary)
                Spacer()
                Text(formatCurrencyCompact(model.income))
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneSecondary)
            }

            // ── Income bar ────────────────────────────────────────────────
            GeometryReader { geo in
                let filled = geo.size.width * CGFloat(model.income / reference)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.monePrimary.opacity(0.45))
                        .frame(width: filled)
                        .zIndex(1)
                    DiagonalHatch()
                        .zIndex(0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: barHeight)

            // ── Outflow label + amount ────────────────────────────────────
            HStack {
                Text("OUTFLOW")
                    .font(.moneLabelCaps)
                    .foregroundStyle(Color.moneTertiary)
                Spacer()
                Text(formatCurrencyCompact(totalOutflow))
                    .font(.moneLabelCaps)
                    .foregroundStyle(totalOutflow > model.income ? Color.moneRisk : Color.moneSecondary)
            }

            // ── Outflow segmented bar ─────────────────────────────────────
            GeometryReader { geo in
                let filled = geo.size.width * CGFloat(totalOutflow / reference)
                let segGaps = CGFloat(max(segments.count - 1, 0)) * 2
                HStack(spacing: 0) {
                    // Coloured segments
                    HStack(spacing: 2) {
                        ForEach(segments.indices, id: \.self) { i in
                            let seg = segments[i]
                            let segWidth = (filled - segGaps) * CGFloat(seg.amount / max(totalOutflow, 1))
                            Rectangle()
                                .fill(segmentColor(seg.kind))
                                .frame(width: max(segWidth, 2))
                        }
                    }
                    .frame(width: filled)
                    .zIndex(1)

                    DiagonalHatch()
                        .zIndex(0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: barHeight)
        }
    }

    private func segmentColor(_ kind: MoneyMapBucketKind) -> Color {
        switch kind {
        case .committed:  return Color.monePrimary.opacity(0.8)
        case .everyday:   return Color.moneSecondary.opacity(0.7)
        case .fund:       return Color.moneHealthy
        case .liability:  return .blue.opacity(0.75)
        case .tax:        return .purple.opacity(0.7)
        case .outliers:   return Color.moneRisk.opacity(0.75)
        case .review:     return .orange.opacity(0.75)
        default:          return Color.moneTertiary.opacity(0.4)
        }
    }
}

/// Simple left-to-right wrapping layout for the legend chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowH + spacing; x = 0; rowH = 0
            }
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowH + spacing; x = bounds.minX; rowH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowH = max(rowH, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Waterfall Chart

private struct MoneyMapWaterfallChart: View {
    let model: MoneyMapScreenModel

    // Label column width measured via preference key
    @State private var labelColWidth: CGFloat = 90

    private var totalOutflow: Double {
        model.waterfallRows
            .filter { $0.kind != .operatingRemaining }
            .map { abs($0.amount) }
            .reduce(0, +)
    }

    var body: some View {
        let reference = max(model.income, totalOutflow, 1)

        VStack(alignment: .leading, spacing: 0) {
            // ── Income reference row ─────────────────────────────────────
            WaterfallBarRow(
                label: "Income",
                amount: model.income,
                fraction: model.income / reference,
                kind: .income,
                isIncome: true,
                labelColWidth: labelColWidth
            )

            // ── Divider ──────────────────────────────────────────────────
            Rectangle()
                .fill(Color.moneStroke.opacity(0.5))
                .frame(height: 1)
                .padding(.vertical, 10)

            // ── Outflow rows ─────────────────────────────────────────────
            ForEach(model.waterfallRows) { row in
                WaterfallBarRow(
                    label: row.label,
                    amount: row.amount,
                    fraction: abs(row.amount) / reference,
                    kind: row.kind,
                    isIncome: false,
                    labelColWidth: labelColWidth
                )
            }
        }
        // Measure the widest label and store it
        .onPreferenceChange(WaterfallLabelWidthKey.self) { value in
            labelColWidth = min(value, 110)
        }
    }
}

private struct WaterfallBarRow: View {
    let label: String
    let amount: Double
    let fraction: CGFloat   // 0…1 relative to income
    let kind: MoneyMapBucketKind
    let isIncome: Bool
    let labelColWidth: CGFloat

    private let barHeight: CGFloat = 18

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Label
            Text(label)
                .font(isIncome ? .moneLabelCaps : .system(size: 11))
                .foregroundStyle(isIncome ? Color.moneTertiary : Color.moneSecondary)
                .lineLimit(1)
                .frame(width: labelColWidth, alignment: .trailing)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: WaterfallLabelWidthKey.self,
                            value: geo.size.width
                        )
                    }
                )

            // Bar + amount
            GeometryReader { geo in
                let barWidth = max(geo.size.width * fraction, fraction > 0 ? 3 : 0)
                HStack(alignment: .center, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: barWidth, height: barHeight)

                    Text(amountText)
                        .font(.system(size: 11, weight: isIncome ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(amountColor)
                        .lineLimit(1)
                }
            }
            .frame(height: barHeight)
        }
        .padding(.vertical, 5)
    }

    private var barColor: Color {
        if isIncome { return Color.moneHealthy.opacity(0.55) }
        switch kind {
        case .committed:          return Color.monePrimary.opacity(0.8)
        case .everyday:           return Color.moneSecondary.opacity(0.7)
        case .fund:               return Color.moneHealthy
        case .liability:          return .blue.opacity(0.75)
        case .tax:                return .purple.opacity(0.7)
        case .outliers:           return Color.moneRisk.opacity(0.75)
        case .review:             return .orange.opacity(0.75)
        case .operatingRemaining: return Color.moneHealthy.opacity(0.35)
        default:                  return Color.moneTertiary.opacity(0.4)
        }
    }

    private var amountColor: Color {
        switch kind {
        case .outliers:           return Color.moneRisk
        case .operatingRemaining: return Color.moneHealthy
        case .fund:               return Color.moneHealthy
        default:                  return Color.monePrimary
        }
    }

    private var amountText: String {
        formatCurrencyCompact(abs(amount))
    }
}

private struct WaterfallLabelWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Segmented Bar (kept for reference, no longer used in snapshot card)

private struct MoneyMapSegmentedBar: View {
    let model: MoneyMapScreenModel

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(model.buckets) { bucket in
                    Rectangle()
                        .fill(color(for: bucket.kind))
                        .frame(width: segmentWidth(bucket.amount, totalWidth: geometry.size.width))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(height: 64)
    }

    private func segmentWidth(_ amount: Double, totalWidth: CGFloat) -> CGFloat {
        guard amount > 0 else { return 0 }
        return max(totalWidth * CGFloat(amount / model.positiveMapTotal), 3)
    }

    private func color(for kind: MoneyMapBucketKind) -> Color {
        switch kind {
        case .committed:
            return Color.monePrimary
        case .everyday:
            return Color.moneSecondary
        case .fund:
            return Color.moneHealthy
        case .liability:
            return .blue
        case .tax:
            return .purple
        case .outliers:
            return Color.moneRisk.opacity(0.75)
        case .review:
            return .orange
        case .operatingRemaining:
            return Color.moneTertiary.opacity(0.35)
        case .liquidCashImpact:
            return Color.moneRisk
        case .income:
            return Color.moneHealthy
        case .cash:
            return Color.moneSecondary
        case .neutral:
            return Color.moneStroke
        }
    }
}

private struct MoneyMapMiniCard: View {
    let item: MoneyMapItem
    var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.moneSecondary)

                Spacer()

                Text(item.status.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 16)

            Text(item.title)
                .font(.moneBodySm)
                .fontWeight(.medium)
                .foregroundStyle(Color.monePrimary)
                .lineLimit(1)
                .padding(.bottom, 8)

            Text(formatCurrency(item.amount))
                .font(.moneAmtMd)
                .foregroundStyle(Color.monePrimary)
                .padding(.bottom, 10)

            if isExpanded, let date = item.dateText {
                Text(date)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.moneSecondary)
                    .padding(.bottom, 6)
            }

            // In grid: fixed spacer keeps height stable (no layout loop).
            // When expanded in overlay: flexible Spacer pushes subtitle to bottom.
            if isExpanded {
                Spacer(minLength: 0)
            } else {
                Color.clear.frame(height: 80)
            }

            Text(item.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Color.moneTertiary)
                .lineLimit(1)
        }
        .padding(20)
        .frame(maxHeight: isExpanded ? .infinity : nil)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    private var statusColor: Color {
        switch item.kind {
        case .review, .outliers:
            return Color.moneRisk
        case .fund:
            return Color.moneHealthy
        default:
            return Color.moneSecondary
        }
    }
}

// MARK: - Subscriptions Mini Card

private struct SubscriptionsMiniCard: View {
    let items: [MoneyMapItem]
    var isExpanded: Bool = false

    private let logoSize: CGFloat = 28
    private let overlap: CGFloat = -4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: repeat icon (left) + status badge (right)
            HStack(alignment: .top) {
                Image(systemName: "repeat")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.moneSecondary)

                Spacer()

                Text("RECURRING")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.moneSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.moneSecondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 14)

            // Logo stack row
            GeometryReader { geo in
                logoStack(availableWidth: geo.size.width)
            }
            .frame(height: logoSize)
            .padding(.bottom, 12)

            Text(formatCurrency(items.map(\.amount).reduce(0, +)))
                .font(.moneAmtMd)
                .foregroundStyle(Color.monePrimary)
                .padding(.bottom, 10)

            if isExpanded {
                Spacer(minLength: 0)
            } else {
                Color.clear.frame(height: 80)
            }

            Text("\(items.count) service\(items.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(Color.moneTertiary)
                .lineLimit(1)
        }
        .padding(20)
        .frame(maxHeight: isExpanded ? .infinity : nil)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }

    @ViewBuilder
    private func logoStack(availableWidth: CGFloat) -> some View {
        // How many logos fit before we need overflow?
        let maxLogos = max(1, Int((availableWidth + overlap) / (logoSize - overlap)))
        let showCount = items.count > maxLogos ? maxLogos - 1 : items.count
        let overflow = items.count - showCount

        HStack(spacing: 0) {
            ForEach(Array(items.prefix(showCount).enumerated()), id: \.offset) { idx, item in
                logoCircle(for: item.title)
                    .offset(x: CGFloat(idx) * -(overlap))
                    .zIndex(Double(showCount - idx))
            }

            if overflow > 0 {
                ZStack {
                    Circle()
                        .fill(Color.moneStroke)
                        .frame(width: logoSize, height: logoSize)
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.moneSecondary)
                }
                .offset(x: CGFloat(showCount) * -(overlap))
            }
        }
    }

    private func logoCircle(for name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.moneSurface)
                .frame(width: logoSize, height: logoSize)
                .overlay(Circle().strokeBorder(Color.moneStroke, lineWidth: 0.5))

            CompanyLogoView(
                query: name,
                fallbackSystemName: subscriptionIcon(for: name),
                padding: 2
            )
            .frame(width: logoSize, height: logoSize)
        }
        .frame(width: logoSize, height: logoSize)
    }

    private func subscriptionIcon(for name: String) -> String {
        let n = name.uppercased()
        if n.contains("NETFLIX")                        { return "play.rectangle.fill" }
        if n.contains("SPOTIFY")                        { return "music.note" }
        if n.contains("APPLE") || n.contains("ICLOUD")  { return "applelogo" }
        if n.contains("AMAZON") || n.contains("PRIME")  { return "shippingbox.fill" }
        if n.contains("YOUTUBE") || n.contains("GOOGLE"){ return "play.circle.fill" }
        if n.contains("HOTSTAR") || n.contains("DISNEY"){ return "sparkles.tv.fill" }
        if n.contains("SWIGGY") || n.contains("ZOMATO") { return "fork.knife.circle.fill" }
        if n.contains("ZEPTO")                          { return "cart.fill" }
        if n.contains("LINKEDIN")                       { return "person.crop.rectangle.stack.fill" }
        if n.contains("GYM") || n.contains("FITNESS")   { return "dumbbell.fill" }
        return "repeat.circle.fill"
    }
}

private struct MoneyMapCategoryCard: View {
    let group: MoneyMapCategoryGroup
    var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(group.title)
                .font(.moneBodySm)
                .fontWeight(.bold)
                .foregroundStyle(Color.monePrimary)
                .lineLimit(2)

            Text(formatCurrency(group.amount))
                .font(.moneAmtMd)
                .foregroundStyle(Color.monePrimary)

            CategorySparkline(group: group, flexible: isExpanded)

            HStack {
                Text("\(group.transactionCount) transaction\(group.transactionCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.moneTertiary)

                Spacer()

                Text(group.status.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(group.status == "High" ? Color.moneRisk : Color.moneSecondary)
                    .padding(.vertical, 3)
                    .background(Color.moneStroke.opacity(0.35))
                    .clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxHeight: isExpanded ? .infinity : nil)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }
}

// MARK: - Category Sparkline

private struct CategorySparkline: View {
    let group: MoneyMapCategoryGroup
    var flexible: Bool = false

    private let chartHeight: CGFloat = 48

    private var lineColor: Color {
        group.status == "High" ? Color.moneRisk : Color.moneSecondary
    }

    var body: some View {
        if group.transactionCount >= 5 {
            rollingLineChart
        } else {
            sparseLineChart
        }
    }

    // ── ≥5 transactions: rolling avg this month (solid) + prev month (faint) ──

    private var rollingLineChart: some View {
        let current  = rollingAverage(group.dailyAmounts, window: 5)
        let previous = rollingAverage(group.previousMonthDailyAmounts, window: 5)

        return Chart {
            // Previous month — lighter, dashed
            ForEach(previous, id: \.day) { pt in
                LineMark(
                    x: .value("Day", pt.day),
                    y: .value("₹", pt.avg),
                    series: .value("Period", "prev")
                )
                .foregroundStyle(lineColor.opacity(0.65))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .interpolationMethod(.catmullRom)
            }

            // Current month — solid
            ForEach(current, id: \.day) { pt in
                LineMark(
                    x: .value("Day", pt.day),
                    y: .value("₹", pt.avg),
                    series: .value("Period", "current")
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: flexible ? nil : chartHeight)
        .frame(maxHeight: flexible ? .infinity : nil)
    }

    // ── <5 transactions: two edge points — prev month total (left), this month total (right) ──

    private var sparseLineChart: some View {
        // x=0 → left edge (prev month), x=1 → right edge (this month)
        let pts: [(x: Int, y: Double, series: String)] = [
            (0, group.previousMonthAmount, "prev"),
            (1, group.amount,              "current")
        ]

        return Chart {
            // Connecting line — dashed, faint for prev → solid for current direction
            ForEach(pts, id: \.x) { pt in
                LineMark(
                    x: .value("Period", pt.x),
                    y: .value("₹", pt.y),
                    series: .value("S", "line")
                )
                .foregroundStyle(lineColor.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.linear)
            }

            // Prev month point — lighter
            PointMark(
                x: .value("Period", 0),
                y: .value("₹", group.previousMonthAmount)
            )
            .foregroundStyle(lineColor.opacity(0.45))
            .symbolSize(24)

            // This month point — solid, slightly larger
            PointMark(
                x: .value("Period", 1),
                y: .value("₹", group.amount)
            )
            .foregroundStyle(lineColor)
            .symbolSize(32)
        }
        .chartXScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: flexible ? nil : chartHeight)
        .frame(maxHeight: flexible ? .infinity : nil)
    }

    // ── Rolling average ────────────────────────────────────────────────────

    private struct RollingPoint {
        let day: Int
        let avg: Double
    }

    private func rollingAverage(_ daily: [CategoryDailyAmount], window: Int) -> [RollingPoint] {
        guard !daily.isEmpty else { return [] }
        let minDay = daily.map(\.day).min()!
        let maxDay = daily.map(\.day).max()!
        var dayMap: [Int: Double] = [:]
        for pt in daily { dayMap[pt.day] = pt.amount }

        return (minDay...maxDay).map { day in
            let windowDays = max(minDay, day - window + 1)...day
            let vals = windowDays.map { dayMap[$0] ?? 0 }
            return RollingPoint(day: day, avg: vals.reduce(0, +) / Double(vals.count))
        }
    }
}

private struct MoneyMapListRow: View {
    let item: MoneyMapItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: item.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(Color.moneSecondary)
                .frame(width: 36, height: 36)
                .background(Color.moneStroke.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.moneBodyMd)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.monePrimary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.moneTertiary)
                    .lineLimit(2)
            }

            Spacer()

            Text(formatCurrency(item.amount))
                .font(.moneAmtSm)
                .foregroundStyle(item.kind == .review || item.kind == .outliers ? Color.moneRisk : Color.monePrimary)
        }
        .padding(20)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }
}

private func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.maximumFractionDigits = 0
    formatter.locale = Locale(identifier: "en_IN")

    return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
}

private func formatCurrencyCompact(_ value: Double) -> String {
    let absValue = abs(value)

    if absValue >= 100_000 {
        let lakhs = value / 100_000
        return String(format: "₹%.2fL", lakhs)
            .replacingOccurrences(of: ".00", with: "")
    }

    return formatCurrency(value)
}

#Preview {
    MoneyMapView()
}
