import SwiftUI

struct TransactionsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var selectedFilter: TransactionCategory = .all
    @State private var showUpcoming = true

    var filtered: [Transaction] {
        let base = appVM.transactions
        if selectedFilter == .all { return base }
        return base.filter { $0.category == selectedFilter }
    }

    var past: [Transaction]     { filtered.filter { !$0.isUpcoming }.sorted { $0.date > $1.date } }
    var upcoming: [Transaction] { filtered.filter { $0.isUpcoming }.sorted { $0.date < $1.date } }

    var filters: [TransactionCategory] {
        [.all, .food, .shopping, .bills, .subscriptions, .creditCard, .transport]
    }

    var body: some View {
        ZStack {
            Color.moneBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("moné").font(.moneLabelCaps).tracking(1.5).foregroundStyle(Color.moneTertiary)
                        Text("Activity").font(.moneHLMd).foregroundStyle(Color.monePrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, MoneSpacing.page)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MoneSpacing.gap) {
                        ForEach(filters, id: \.rawValue) { cat in
                            FilterChip(
                                title: cat.rawValue,
                                isSelected: selectedFilter == cat
                            ) {
                                selectedFilter = cat
                            }
                        }
                    }
                    .padding(.horizontal, MoneSpacing.page)
                }
                .padding(.bottom, 12)

                Divider().background(Color.moneStroke)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: MoneSpacing.gutter) {

                        // Upcoming section
                        if !upcoming.isEmpty {
                            VStack(alignment: .leading, spacing: MoneSpacing.gap) {
                                HStack {
                                    Text("UPCOMING")
                                        .moneLabelCaps()
                                    Spacer()
                                    Button {
                                        showUpcoming.toggle()
                                    } label: {
                                        Image(systemName: showUpcoming ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.moneTertiary)
                                    }
                                }

                                if showUpcoming {
                                    VStack(spacing: 0) {
                                        ForEach(upcoming) { tx in
                                            TransactionRow(transaction: tx)
                                            if tx.id != upcoming.last?.id {
                                                Divider().background(Color.moneStroke).padding(.horizontal, MoneSpacing.cardSm)
                                            }
                                        }
                                    }
                                    .moneCard()
                                }
                            }
                        }

                        // Past transactions
                        if !past.isEmpty {
                            Text("RECENT")
                                .moneLabelCaps()

                            VStack(spacing: 0) {
                                ForEach(past) { tx in
                                    TransactionRow(transaction: tx)
                                    if tx.id != past.last?.id {
                                        Divider().background(Color.moneStroke).padding(.horizontal, MoneSpacing.cardSm)
                                    }
                                }
                            }
                            .moneCard()
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, MoneSpacing.page)
                    .padding(.top, MoneSpacing.gutter)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showUpcoming)
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: MoneSpacing.gutter) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: MoneRadius.sm, style: .continuous)
                    .fill(transaction.isUpcoming ? Color.moneRiskBg : Color.moneSurfaceEl)
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(transaction.isUpcoming ? Color.moneRisk : Color.moneSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.moneHLSm)
                    .foregroundStyle(Color.monePrimary)
                Text(transaction.dateLabel)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.amountFormatted)
                    .font(.moneAmtSm)
                    .foregroundStyle(transaction.isUpcoming ? Color.moneRisk : Color.monePrimary)
                Text(transaction.category.rawValue)
                    .font(.moneBodySm)
                    .foregroundStyle(Color.moneTertiary)
            }
        }
        .padding(.horizontal, MoneSpacing.cardSm)
        .padding(.vertical, 12)
    }
}

#Preview {
    TransactionsView()
        .environment(AppViewModel())
}
