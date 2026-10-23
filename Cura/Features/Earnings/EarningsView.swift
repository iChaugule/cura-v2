import SwiftUI

struct EarningsView: View {
    @State private var selectedPeriod: EarningsPeriod = .thisMonth

    enum EarningsPeriod: String, CaseIterable {
        case thisWeek = "This week"
        case thisMonth = "This month"
        case lastMonth = "Last month"
    }

    private let visits: [VisitEarning] = [
        VisitEarning(date: Calendar.current.date(byAdding: .day, value: -0, to: Date())!, family: "Rao Family (Aaji)", hours: 6, rate: 350, status: .pending),
        VisitEarning(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, family: "Rao Family (Aaji)", hours: 6, rate: 350, status: .pending),
        VisitEarning(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, family: "Kulkarni Family (Kaka)", hours: 4, rate: 320, status: .paid),
        VisitEarning(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, family: "Rao Family (Aaji)", hours: 6, rate: 350, status: .paid),
        VisitEarning(date: Calendar.current.date(byAdding: .day, value: -8, to: Date())!, family: "Pawar Family (Tai)", hours: 4, rate: 320, status: .paid),
        VisitEarning(date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, family: "Joshi Family (Nana)", hours: 4, rate: 320, status: .paid),
        VisitEarning(date: Calendar.current.date(byAdding: .day, value: -12, to: Date())!, family: "Rao Family (Aaji)", hours: 6, rate: 350, status: .paid),
    ]

    var totalThisMonth: Int { visits.reduce(0) { $0 + ($1.hours * $1.rate) } }
    var pendingTotal: Int { visits.filter { $0.status == .pending }.reduce(0) { $0 + ($1.hours * $1.rate) } }
    var paidTotal: Int { visits.filter { $0.status == .paid }.reduce(0) { $0 + ($1.hours * $1.rate) } }
    var upcomingTotal: Int = 1680

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    summaryHeader
                    summaryCards
                    periodPicker
                    visitBreakdown
                    downloadButton
                    disclaimerLabel
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Earnings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        CareCard {
            VStack(spacing: Spacing.sm) {
                Text("This Month")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                Text("₹\(totalThisMonth)")
                    .font(.careDisplayLarge)
                    .foregroundStyle(.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.carePositive)
                        .font(.caption)
                    Text("\(visits.filter { $0.status == .paid }.count) visits completed")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Earnings this month: ₹\(totalThisMonth). \(visits.filter { $0.status == .paid }.count) visits completed.")
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Spacing.sm) {
            earningsSummaryCard(title: "Upcoming", amount: upcomingTotal, color: .careAccentBlue)
            earningsSummaryCard(title: "Pending", amount: pendingTotal, color: .careAttention)
            earningsSummaryCard(title: "Paid", amount: paidTotal, color: .carePositive)
        }
    }

    private func earningsSummaryCard(title: String, amount: Int, color: Color) -> some View {
        CareCard {
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                Text("₹\(amount)")
                    .font(.careHeading)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): ₹\(amount)")
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(EarningsPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Visit Breakdown

    private var visitBreakdown: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Visit breakdown")

            VStack(spacing: Spacing.xs) {
                ForEach(visits) { visit in
                    visitRow(visit)
                }
            }
        }
    }

    private func visitRow(_ visit: VisitEarning) -> some View {
        CareCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.family)
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                    HStack(spacing: Spacing.xs) {
                        Text(visit.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                        Text("·")
                            .foregroundStyle(.textSecondary)
                        Text("\(visit.hours) hrs × ₹\(visit.rate)/hr")
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("₹\(visit.hours * visit.rate)")
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                    Text(visit.status.label)
                        .font(.careCaption)
                        .foregroundStyle(visit.status.color)
                }
            }
            .padding(Spacing.md)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(visit.family), \(visit.date.formatted(date: .abbreviated, time: .omitted)), ₹\(visit.hours * visit.rate), \(visit.status.label)")
    }

    // MARK: - Download

    private var downloadButton: some View {
        Button {
            // Download statement
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundStyle(.careAccentBlue)
                Text("Download Statement")
                    .font(.careBodyMedium)
                    .foregroundStyle(.careAccentBlue)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.careAccentBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .accessibilityLabel("Download earnings statement")
    }

    private var disclaimerLabel: some View {
        Text("Fictional demonstration data. No real earnings or payments are represented.")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Models

struct VisitEarning: Identifiable {
    let id = UUID()
    let date: Date
    let family: String
    let hours: Int
    let rate: Int
    let status: PaymentStatus
}

enum PaymentStatus {
    case upcoming, pending, paid

    var label: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .pending: return "Pending"
        case .paid: return "Paid"
        }
    }

    var color: Color {
        switch self {
        case .upcoming: return .careAccentBlue
        case .pending: return .careAttention
        case .paid: return .carePositive
        }
    }
}

#Preview {
    EarningsView()
}
