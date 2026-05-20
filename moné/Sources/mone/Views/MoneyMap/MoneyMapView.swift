import SwiftUI
import SwiftData

struct MoneyMapView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var model: MoneyMapScreenModel?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: MoneSpacing.gutter) {
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
    }

    private func header(_ model: MoneyMapScreenModel) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("moné")
                    .font(.moneLabelCaps)
                    .tracking(1.5)
                    .foregroundStyle(Color.moneTertiary)

                Text("Money Map")
                    .font(.moneHLMd)
                    .foregroundStyle(Color.monePrimary)

                Text("\(model.displayName.capitalized) · \(model.month)")
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly inflow recon")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneTertiary)

                    Text(formatCurrencyCompact(model.income))
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .foregroundStyle(Color.monePrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(model.confidence)% confidence")
                        .font(.moneLabelCaps)
                        .foregroundStyle(confidenceColor(model.confidence))

                    Text("\(model.transactionCount) signals")
                        .font(.moneBodySm)
                        .foregroundStyle(Color.moneTertiary)
                }
            }

            MoneyMapSegmentedBar(model: model)

            bucketGrid(model)

            Divider()
                .background(Color.moneStroke)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Operating position")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneTertiary)

                    Spacer()

                    Text(formatCurrency(model.operatingRemaining))
                        .font(.moneBodyLg)
                        .foregroundStyle(model.operatingRemaining < 0 ? Color.moneRisk : Color.monePrimary)
                }

                HStack {
                    Text("Liquid cash impact")
                        .font(.moneLabelCaps)
                        .foregroundStyle(Color.moneTertiary)

                    Spacer()

                    Text(formatCurrency(model.liquidCashImpact))
                        .font(.moneBodyLg)
                        .foregroundStyle(model.liquidCashImpact < 0 ? Color.moneRisk : Color.monePrimary)
                }

                Text("Tax and unusual deductions are separated from operating affordability so they do not distort safe-to-spend.")
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }
        }
        .padding(MoneSpacing.cardSm)
        .moneCard()
    }

    private func bucketGrid(_ model: MoneyMapScreenModel) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 16
        ) {
            moneyLabel("Committed", model.regularCommitted, .committed)
            moneyLabel("Everyday", model.everyday, .everyday)
            moneyLabel("Fund", model.fund, .fund)
            moneyLabel("Liability", model.liability, .liability)
            moneyLabel("Tax", model.taxDeduction, .tax)
            moneyLabel("Review", model.review, .review)
        }
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                    .foregroundStyle(Color.monePrimary)

                Spacer()

                Text(trailing)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneSecondary)
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.moneStroke)
                    .frame(height: 0.5)
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
            .moneCard()
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
        .moneCard()
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
        case .neutral:
            return Color.moneStroke
        }
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
        .frame(height: 42)
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
        case .neutral:
            return Color.moneStroke
        }
    }
}

private struct MoneyMapMiniCard: View {
    let item: MoneyMapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.moneBodySm)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.monePrimary)
                    .lineLimit(1)

                Text(formatCurrency(item.amount))
                    .font(.moneBodySm)
                    .foregroundStyle(Color.monePrimary)

                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.moneTertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .moneCard()
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
        VStack(alignment: .leading, spacing: 12) {
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
                .font(.moneBodyMd)
                .foregroundStyle(Color.monePrimary)

            MicroTrendLine(isHigh: group.status == "High")

            Text("\(group.transactionCount) transaction\(group.transactionCount == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundStyle(Color.moneTertiary)
        }
        .padding(14)
        .moneCard()
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
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(size: 16))
                .foregroundStyle(Color.moneSecondary)
                .frame(width: 28, height: 28)
                .background(Color.moneStroke.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.moneBodySm)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.monePrimary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.moneTertiary)
                    .lineLimit(2)
            }

            Spacer()

            Text(formatCurrency(item.amount))
                .font(.moneBodySm)
                .foregroundStyle(item.kind == .review || item.kind == .outliers ? Color.moneRisk : Color.monePrimary)
        }
        .padding(14)
        .moneCard()
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
