import SwiftUI
import SwiftData

struct MoneyMapView: View {
    @Environment(SessionViewModel.self) private var sessionVM
    @Environment(\.modelContext) private var modelContext

    @State private var model: MoneyMapScreenModel?
    @State private var errorMessage: String?
    @State private var showTransactionHistory = false

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 36) {
                    if let model {
                        header(model)
                        snapshotCard(model)
                        committedSection(model)
                        everydaySection(model)
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
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 16)
            }
        }
        .task {
            loadMoneyMap()
        }
        .sheet(isPresented: $showTransactionHistory) {
            if let model {
                MoneyMapTransactionHistorySheet(
                    model: model,
                    onRetag: { transaction, option in
                        retag(transaction, as: option)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.moneBackground)
            }
        }
    }

    private func header(_ model: MoneyMapScreenModel) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("moné")
                    .font(.moneLabelCaps)
                    .tracking(3.0)
                    .foregroundStyle(Color.moneTertiary)

                Text("Money Map")
                    .font(.moneDisplay)
                    .foregroundStyle(Color.monePrimary)

                Text(sessionVM.isSignedIn
                     ? "\(sessionVM.displayName.capitalized) · \(model.month)"
                     : model.month)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }

            Spacer()

            Circle()
                .fill(confidenceColor(model.confidence))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .strokeBorder(confidenceColor(model.confidence).opacity(0.25), lineWidth: 4)
                )
        }
    }

    private func snapshotCard(_ model: MoneyMapScreenModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {

            // ── Income + Confidence ──────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(model.month.uppercased()) INFLOW RECON")
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

            // ── Segmented bar ────────────────────────────────────────────
            MoneyMapSegmentedBar(model: model)

            // ── Bucket grid ──────────────────────────────────────────────
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 16
            ) {
                moneyLabel("Committed",  model.regularCommitted,         .committed)
                moneyLabel("Everyday",   model.everyday,                 .everyday)
                moneyLabel("Fund",       model.fund,                     .fund)
                moneyLabel("Outliers",   model.outliers,                 .outliers)
                moneyLabel("Review",     model.review,                   .review)
                moneyLabel("Remaining",  model.operatingRemaining,       .operatingRemaining)
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
                        .font(.moneBodyLg)
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
                    .font(.moneBodySm)
                    .foregroundStyle(Color.monePrimary)
            }
        }
        .frame(minHeight: 42, alignment: .leading)
    }

    private func committedSection(_ model: MoneyMapScreenModel) -> some View {
        section(
            title: "Monthly committed",
            trailing: "\(formatCurrency(model.regularCommitted)) detected"
        ) {
            if model.committedItems.isEmpty {
                emptySection("No recurring commitments detected for this month.")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(model.committedItems) { item in
                        MoneyMapMiniCard(item: item)
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
                    }
                }
            }
        }
    }

    private func outliersSection(_ model: MoneyMapScreenModel) -> some View {
        section(
            title: "Outliers",
            trailing: "\(formatCurrency(model.outliers)) unusual"
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
    let onRetag: (MoneyMapTransaction, MoneyMapRetagOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: MoneyMapTransactionFilter = .all

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
                        .font(.moneBodyMd)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 16))
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

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.moneBodySm)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.monePrimary)
                    .lineLimit(1)

                Text(formatCurrency(item.amount))
                    .font(.moneBodyMd)
                    .foregroundStyle(Color.monePrimary)

                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.moneTertiary)
                    .lineLimit(1)
            }
        }
        .padding(20)
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

private struct MoneyMapCategoryCard: View {
    let group: MoneyMapCategoryGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(group.title)
                    .font(.moneBodySm)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.monePrimary)
                    .lineLimit(1)

                Spacer()

                Text(group.status.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(group.status == "High" ? Color.moneRisk : Color.moneSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.moneStroke.opacity(0.35))
                    .clipShape(Capsule())
            }

            Text(formatCurrency(group.amount))
                .font(.moneBodyLg)
                .foregroundStyle(Color.monePrimary)

            MicroTrendLine(isHigh: group.status == "High")

            Text("\(group.transactionCount) transaction\(group.transactionCount == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(Color.moneTertiary)
        }
        .padding(20)
        .moneCard(radius: MoneRadius.xl, elevated: true)
    }
}

private struct MicroTrendLine: View {
    let isHigh: Bool

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                path.move(to: CGPoint(x: 0, y: height * 0.8))
                path.addCurve(
                    to: CGPoint(x: width, y: isHigh ? height * 0.15 : height * 0.45),
                    control1: CGPoint(x: width * 0.25, y: height * 0.85),
                    control2: CGPoint(x: width * 0.65, y: isHigh ? height * 0.05 : height * 0.55)
                )
            }
            .stroke(isHigh ? Color.moneRisk : Color.moneSecondary, lineWidth: 1.5)
        }
        .frame(height: 38)
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
                .font(.moneBodyMd)
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




