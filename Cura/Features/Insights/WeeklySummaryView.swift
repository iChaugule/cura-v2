import SwiftUI
import Charts

// MARK: - ViewModel

@MainActor
@Observable
final class WeeklySummaryViewModel {
    var summary: WeeklySummary = SampleData.weeklySummary
    var isLoading: Bool = false
    var showShareSheet: Bool = false
    var lovedOne: LovedOne = SampleData.lovedOne

    var weekLabel: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: summary.weekStart, to: summary.weekEnd)
    }

    func load(container: ServiceContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await container.insightsService.weeklySummary(for: SampleData.lovedOne.id)
        } catch { }
    }
}

// MARK: - Domain chart point

struct DomainDataPoint: Identifiable {
    let id: String
    let day: Int
    let dayLabel: String
    let score: Double
    let domain: String
}

// MARK: - Main View

struct WeeklySummaryView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = WeeklySummaryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    domainTrendCards
                    steadySections
                    changedSection
                    doctorQuestionsSection
                    disclaimerSection
                    demoDisclaimer
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weekly Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
            .task { await viewModel.load(container: container) }
            .sheet(isPresented: $viewModel.showShareSheet) { shareSheet }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: Spacing.xxs) {
            Text("Week of")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .textCase(.uppercase)
            Text(viewModel.weekLabel)
                .font(.careDisplayMedium)
                .foregroundStyle(.textPrimary)
            Text(viewModel.lovedOne.name)
                .font(.careSubheading)
                .foregroundStyle(.careAccentBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    // MARK: Domain Trend Cards

    private var domainTrendCards: some View {
        VStack(spacing: Spacing.sm) {
            SectionHeader(title: "7-day trends")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(viewModel.summary.domainScores) { domain in
                    domainTrendCard(domain)
                }
            }
        }
    }

    private func domainTrendCard(_ domain: DomainScore) -> some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(domainEmoji(domain.domain))
                        .font(.title3)
                    Text(domain.domain)
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                }
                trendChart(for: domain)
                    .frame(height: 64)
                trendBandLabel(domain.trend)
            }
            .padding(Spacing.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(domain.domain) trend: \(trendBandText(domain.trend))")
    }

    private func trendChart(for domain: DomainScore) -> some View {
        let points = chartPoints(for: domain)
        return Chart(points) { point in
            LineMark(
                x: .value("Day", point.day),
                y: .value("Score", point.score)
            )
            .foregroundStyle(trendColor(domain.trend))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Day", point.day),
                yStart: .value("Min", 0),
                yEnd: .value("Score", point.score)
            )
            .foregroundStyle(trendColor(domain.trend).opacity(0.12))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...100)
    }

    private func trendBandLabel(_ trend: TrajectoryLabel) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: trendIcon(trend))
                .font(.caption.weight(.semibold))
            Text(trendBandText(trend))
                .font(.careCaption)
        }
        .foregroundStyle(trendColor(trend))
    }

    // MARK: Steady Section

    private var steadySections: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "What stayed steady")
            CareCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(viewModel.summary.whatStayed, id: \.self) { item in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: "equal.circle.fill")
                                .foregroundStyle(.carePositive)
                                .font(.body)
                            Text(item)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: Changed Section

    private var changedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "What changed")
            CareCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(viewModel.summary.whatChanged, id: \.description) { change in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: change.direction == .improved ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(change.direction == .improved ? .carePositive : .careAttention)
                                .font(.body)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(change.domain)
                                    .font(.careBodyMedium)
                                    .foregroundStyle(.textPrimary)
                                Text(change.description)
                                    .font(.careBody)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: Doctor Questions

    private var doctorQuestionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Questions for the doctor")
            CareCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(.careAccentBlue)
                        Text("Based on this week's patterns")
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                    ForEach(Array(viewModel.summary.questionsForDoctor.enumerated()), id: \.offset) { index, question in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Text("\(index + 1).")
                                .font(.careBodyMedium)
                                .foregroundStyle(.careAccentBlue)
                                .frame(width: 20, alignment: .leading)
                            Text(question)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: Disclaimer

    private var disclaimerSection: some View {
        Text("This summary is generated from logged care records only. It does not constitute medical advice and should not be used as a substitute for professional medical assessment.")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.sm)
    }

    private var demoDisclaimer: some View {
        Text("Fictional demonstration data")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: Share Sheet

    private var shareSheet: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "square.and.arrow.up")
                .font(.largeTitle)
                .foregroundStyle(.careAccentBlue)
            Text("Export Weekly Summary")
                .font(.careDisplayMedium)
            Text("Choose how to share this summary.")
                .font(.careBody)
                .foregroundStyle(.textSecondary)
            VStack(spacing: Spacing.sm) {
                shareOptionRow(icon: "envelope.fill", label: "Send as Email")
                shareOptionRow(icon: "printer.fill", label: "Print PDF")
                shareOptionRow(icon: "doc.fill", label: "Save to Files")
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(Spacing.xl)
        .presentationDetents([.medium])
    }

    private func shareOptionRow(icon: String, label: String) -> some View {
        Button {
            viewModel.showShareSheet = false
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(.careAccentBlue)
                    .frame(width: 28)
                Text(label)
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.textSecondary)
                    .font(.caption)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.showShareSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Export weekly summary")
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: Helpers

    private func chartPoints(for domain: DomainScore) -> [DomainDataPoint] {
        domain.weeklyScores.enumerated().map { idx, score in
            DomainDataPoint(
                id: "\(domain.domain)-\(idx)",
                day: idx,
                dayLabel: dayLabel(for: idx),
                score: score,
                domain: domain.domain
            )
        }
    }

    private func dayLabel(for index: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return days[safe: index] ?? "Day \(index)"
    }

    private func domainEmoji(_ domain: String) -> String {
        switch domain.lowercased() {
        case "sleep":     return "🌙"
        case "hydration": return "💧"
        case "mood":      return "😊"
        case "mobility":  return "🚶"
        case "food", "eating": return "🍽"
        default:          return "📊"
        }
    }

    private func trendIcon(_ trend: TrajectoryLabel) -> String {
        switch trend {
        case .steady:          return "equal"
        case .slightlyChanged: return "arrow.up.right"
        case .notablyChanged:  return "arrow.up.right"
        case .needsAttention:  return "exclamationmark"
        case .notRecorded:     return "minus"
        }
    }

    private func trendBandText(_ trend: TrajectoryLabel) -> String {
        switch trend {
        case .steady:          return "Steady"
        case .slightlyChanged: return "Slightly changed"
        case .notablyChanged:  return "Notably changed"
        case .needsAttention:  return "Needs attention"
        case .notRecorded:     return "Not recorded"
        }
    }

    private func trendColor(_ trend: TrajectoryLabel) -> Color {
        switch trend {
        case .steady:          return .carePositive
        case .slightlyChanged: return .careAttention
        case .notablyChanged:  return .careAttention
        case .needsAttention:  return .careUrgent
        case .notRecorded:     return .textSecondary
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    WeeklySummaryView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
