import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class AlertDetailViewModel {
    var alert: ConcernAlert
    var showTechnicalDetails: Bool = false
    var feedbackSubmitted: Bool = false
    var selectedFeedback: AlertFeedback? = nil
    var isAcknowledging: Bool = false

    init(alert: ConcernAlert) {
        self.alert = alert
    }

    func acknowledge(container: ServiceContainer) async {
        isAcknowledging = true
        defer { isAcknowledging = false }
        do {
            try await container.insightsService.acknowledgeAlert(alertId: alert.id)
            alert.isAcknowledged = true
        } catch { }
    }

    func submitFeedback(_ feedback: AlertFeedback, container: ServiceContainer) async {
        selectedFeedback = feedback
        feedbackSubmitted = true
        do {
            try await container.insightsService.submitAlertFeedback(alertId: alert.id, feedback: feedback.rawValue)
        } catch { }
    }
}

enum AlertFeedback: String, CaseIterable, Identifiable {
    case helpful     = "Helpful"
    case alreadyKnew = "Already knew"
    case expected    = "Expected"
    case notUseful   = "Not useful"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .helpful:     return "hand.thumbsup.fill"
        case .alreadyKnew: return "checkmark.circle.fill"
        case .expected:    return "equal.circle.fill"
        case .notUseful:   return "hand.thumbsdown.fill"
        }
    }
}

// MARK: - Main View

struct AlertDetailView: View {
    let alert: ConcernAlert
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel: AlertDetailViewModel

    init(alert: ConcernAlert) {
        self.alert = alert
        self._viewModel = State(initialValue: AlertDetailViewModel(alert: alert))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                alertHeader
                whatChangedSection
                comparedToUsualSection
                whenItStartedSection
                alternativeExplanationsSection
                missingDataSection
                whatToDoSection
                confidenceSection
                feedbackSection
                technicalSection
                disclaimerSection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Alert Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    // MARK: Header

    private var alertHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            StatusBadge(
                icon: tierIcon(viewModel.alert.tier),
                label: tierLabel(viewModel.alert.tier),
                tier: viewModel.alert.tier
            )
            Text(viewModel.alert.headline)
                .font(.careDisplayMedium)
                .foregroundStyle(.textPrimary)
            HStack(spacing: Spacing.xs) {
                Text("Created")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                Text(viewModel.alert.createdAt, style: .relative)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                Text("·")
                    .foregroundStyle(.textSecondary)
                Text("Updated")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                Text(viewModel.alert.updatedAt, style: .relative)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.sm)
    }

    // MARK: What Changed

    private var whatChangedSection: some View {
        detailSection(
            icon: "chart.xyaxis.line",
            title: "What changed",
            color: tierColor(viewModel.alert.tier)
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(viewModel.alert.supportingObservations) { observation in
                    observationRow(observation)
                }
            }
        }
    }

    private func observationRow(_ obs: Observation) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tierColor(viewModel.alert.tier))
                .frame(width: 3)
                .frame(minHeight: 40)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(obs.timestamp, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Text(obs.caregiverName)
                        .font(.careCaption)
                        .foregroundStyle(.careAccentBlue)
                }
                Text(obs.note)
                    .font(.careBody)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Observation by \(obs.caregiverName): \(obs.note)")
    }

    // MARK: Compared to Usual

    private var comparedToUsualSection: some View {
        detailSection(
            icon: "arrow.left.arrow.right.circle.fill",
            title: "Compared to usual",
            color: .careAccentBlue
        ) {
            VStack(spacing: Spacing.sm) {
                comparisonRow(
                    label: "Baseline",
                    value: viewModel.alert.anchorBaseline,
                    color: .carePositive
                )
                comparisonRow(
                    label: "Recently",
                    value: viewModel.alert.recentPattern,
                    color: tierColor(viewModel.alert.tier)
                )
            }
        }
    }

    private func comparisonRow(label: String, value: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(label)
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.sm)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: When It Started

    private var whenItStartedSection: some View {
        detailSection(
            icon: "clock.arrow.circlepath",
            title: "When it started",
            color: .careAttention
        ) {
            Text(viewModel.alert.whenItStarted)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
        }
    }

    // MARK: Alternative Explanations

    private var alternativeExplanationsSection: some View {
        detailSection(
            icon: "lightbulb.fill",
            title: "Alternative explanations",
            color: .careCalm
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(Array(viewModel.alert.alternativeExplanations.enumerated()), id: \.offset) { index, explanation in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("\(index + 1).")
                            .font(.careBodyMedium)
                            .foregroundStyle(.careCalm)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(explanation.explanation)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                            Text("Likelihood: \(explanation.likelihood)")
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Missing Data

    private var missingDataSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.careAttention)
                Text("What's missing")
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)
            }
            Text("Cura could be more certain with this information:")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
            ForEach(viewModel.alert.missingDataPoints, id: \.self) { point in
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.careAttention)
                        .font(.caption)
                    Text(point)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.careAttention.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.careAttention.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: What To Do

    private var whatToDoSection: some View {
        detailSection(
            icon: "checklist",
            title: "What to do",
            color: .careAccentBlue
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                actionRow(rank: 1, label: "Message the caregiver",  icon: "message.fill",            color: .careAccentBlue)
                actionRow(rank: 2, label: "Notify your care circle", icon: "person.3.fill",           color: .careAccentTeal)
                actionRow(rank: 3, label: "Contact the doctor",     icon: "stethoscope",             color: .careAttention)
                actionRow(rank: 4, label: "Call emergency services", icon: "phone.badge.plus.fill",   color: .careUrgent)
            }
        }
    }

    private func actionRow(rank: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("\(rank)")
                    .font(.careBodyMedium)
                    .foregroundStyle(color)
            }
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.careBodyMedium)
                .foregroundStyle(.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Action \(rank): \(label)")
    }

    // MARK: Confidence

    private var confidenceSection: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: confidenceIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(confidenceColor)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Confidence: \(viewModel.alert.confidence.label)")
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                Text(viewModel.alert.confidence.explanation)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(confidenceColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confidence \(viewModel.alert.confidence.label): \(viewModel.alert.confidence.explanation)")
    }

    private var confidenceIcon: String {
        switch viewModel.alert.confidence.level {
        case .high:     return "checkmark.seal.fill"
        case .moderate: return "seal.fill"
        case .low:      return "questionmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        switch viewModel.alert.confidence.level {
        case .high:     return .carePositive
        case .moderate: return .careAttention
        case .low:      return .textSecondary
        }
    }

    // MARK: Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Was this useful?")
                .font(.careBodyMedium)
                .foregroundStyle(.textPrimary)
            if viewModel.feedbackSubmitted {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.carePositive)
                    Text("Thanks for your feedback")
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                }
            } else {
                HStack(spacing: Spacing.xs) {
                    ForEach(AlertFeedback.allCases) { feedback in
                        feedbackButton(feedback)
                    }
                }
            }
        }
    }

    private func feedbackButton(_ feedback: AlertFeedback) -> some View {
        Button {
            Task { await viewModel.submitFeedback(feedback, container: container) }
        } label: {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: feedback.icon)
                    .font(.body)
                    .foregroundStyle(.careAccentBlue)
                Text(feedback.rawValue)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Feedback: \(feedback.rawValue)")
    }

    // MARK: Technical Details (collapsible)

    private var technicalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showTechnicalDetails.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right.circle.fill")
                        .rotationEffect(.degrees(viewModel.showTechnicalDetails ? 90 : 0))
                        .foregroundStyle(.textSecondary)
                    Text("Show technical explanation")
                        .font(.careBodyMedium)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                }
            }
            .frame(minHeight: 44)
            .accessibilityLabel("Toggle technical details. \(viewModel.showTechnicalDetails ? "Expanded" : "Collapsed")")

            if viewModel.showTechnicalDetails {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    technicalRow("Supporting observations", "\(viewModel.alert.supportingObservations.count) entries")
                    technicalRow("Detector", viewModel.alert.detectorName)
                    technicalRow("Baseline version", viewModel.alert.baselineVersion)
                    technicalRow("Confidence score", String(format: "%.0f%%", viewModel.alert.confidence.numericScore * 100))
                    technicalRow("Alert ID", viewModel.alert.id)
                }
                .padding(Spacing.md)
                .background(Color.surfaceDepressed)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
        }
    }

    private func technicalRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
            Spacer()
            Text(value)
                .font(.careCaption)
                .foregroundStyle(.textPrimary)
        }
    }

    // MARK: Disclaimer

    private var disclaimerSection: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "info.circle")
                .foregroundStyle(.textSecondary)
            Text("Cura concern alerts are generated from logged care records only. They do not constitute medical advice and do not replace professional medical assessment. Always consult a qualified healthcare professional for medical decisions.")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await viewModel.acknowledge(container: container) }
            } label: {
                Image(systemName: viewModel.alert.isAcknowledged ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.alert.isAcknowledged ? .carePositive : .careAccentBlue)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(viewModel.alert.isAcknowledged ? "Acknowledged" : "Acknowledge this alert")
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func detailSection<Content: View>(
        icon: String,
        title: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.careHeading)
                        .foregroundStyle(.textPrimary)
                }
                content()
            }
            .padding(Spacing.md)
        }
    }

    private func tierIcon(_ tier: AlertTier) -> String {
        switch tier {
        case .urgent:         return "exclamationmark.circle.fill"
        case .monitorClosely: return "exclamationmark.triangle.fill"
        case .informational:  return "info.circle.fill"
        }
    }

    private func tierLabel(_ tier: AlertTier) -> String {
        switch tier {
        case .urgent:         return "Urgent"
        case .monitorClosely: return "Monitor closely"
        case .informational:  return "Informational"
        }
    }

    private func tierColor(_ tier: AlertTier) -> Color {
        switch tier {
        case .urgent:         return .careUrgent
        case .monitorClosely: return .careAttention
        case .informational:  return .careAccentBlue
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AlertDetailView(alert: SampleData.activeAlerts[0])
    }
    .environment(ServiceContainer.preview)
    .environment(AppSession.preview)
}
