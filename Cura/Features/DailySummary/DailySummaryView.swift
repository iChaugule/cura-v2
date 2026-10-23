import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class DailySummaryViewModel {
    var summary: DailyCareLog = SampleData.dailyCareLog
    var lovedOne: LovedOne = SampleData.lovedOne
    var date: Date = Date()
    var isLoading: Bool = false

    var confirmedEvents: [String] {
        summary.confirmedEvents
    }

    var caregiverObservations: [String] {
        summary.caregiverObservations
    }

    var missingInformation: [String] {
        summary.missingInformation
    }

    var uncompletedTasks: [String] {
        summary.uncompletedTaskDescriptions
    }

    func load(container: ServiceContainer, date: Date) async {
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await container.timelineService.dailyLog(for: SampleData.lovedOne.id, on: date)
        } catch { }
    }
}

// MARK: - Main View

struct DailySummaryView: View {
    var date: Date = Date()
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = DailySummaryViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    if !viewModel.confirmedEvents.isEmpty {
                        confirmedEventsSection
                    }
                    if !viewModel.caregiverObservations.isEmpty {
                        observationsSection
                    }
                    if !viewModel.missingInformation.isEmpty {
                        missingInfoSection
                    }
                    if !viewModel.uncompletedTasks.isEmpty {
                        uncompletedTasksSection
                    }
                    summaryTextSection
                    bottomActions
                    demoDisclaimer
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load(container: container, date: date) }
            .navigationDestination(for: DailySummaryDestination.self) { dest in
                switch dest {
                case .timeline: TimelineView()
                case .messaging: FamilyMessagingView()
                }
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: Spacing.xs) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .textCase(.uppercase)
            Text("\(viewModel.lovedOne.name)'s Daily Summary")
                .font(.careDisplayMedium)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    // MARK: Confirmed Events — calm green

    private var confirmedEventsSection: some View {
        summaryBox(
            icon: "checkmark.circle.fill",
            title: "Confirmed this visit",
            color: .carePositive,
            items: viewModel.confirmedEvents
        )
    }

    // MARK: Observations — blue

    private var observationsSection: some View {
        summaryBox(
            icon: "eye.fill",
            title: "Caregiver observations",
            color: .careAccentBlue,
            items: viewModel.caregiverObservations
        )
    }

    // MARK: Missing Info — amber

    private var missingInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.careAttention)
                    .font(.body.weight(.semibold))
                Text("Information not recorded")
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)
            }
            ForEach(viewModel.missingInformation, id: \.self) { item in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.careAttention)
                        .font(.caption)
                        .padding(.top, 3)
                    Text(item)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.careAttention.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.careAttention.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Missing information: \(viewModel.missingInformation.joined(separator: ". "))")
    }

    // MARK: Uncompleted Tasks — red outline

    private var uncompletedTasksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.careUrgent)
                    .font(.body.weight(.semibold))
                Text("Tasks not completed")
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)
            }
            ForEach(viewModel.uncompletedTasks, id: \.self) { task in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "circle")
                        .foregroundStyle(.careUrgent)
                        .font(.caption)
                        .padding(.top, 3)
                    Text(task)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.careUrgent.opacity(0.5), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Uncompleted tasks: \(viewModel.uncompletedTasks.joined(separator: ". "))")
    }

    // MARK: Summary Text

    private var summaryTextSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Summary")
            Text(viewModel.summary.summaryText)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                navigationPath.append(DailySummaryDestination.timeline)
            } label: {
                Label("Full Timeline", systemImage: "clock.fill")
                    .font(.careBodyMedium)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle(style: .secondary))
            .accessibilityLabel("Open full timeline for this day")

            Button {
                navigationPath.append(DailySummaryDestination.messaging)
            } label: {
                Label("Contact Caregiver", systemImage: "message.fill")
                    .font(.careBodyMedium)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle(style: .primary))
            .accessibilityLabel("Message the caregiver")
        }
    }

    // MARK: Demo Disclaimer

    private var demoDisclaimer: some View {
        Text("Fictional demonstration data")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: Helper

    private func summaryBox(icon: String, title: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)
            }
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color)
                        .font(.caption)
                        .padding(.top, 3)
                    Text(item)
                        .font(.careBody)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.md)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(items.joined(separator: ". "))")
    }
}

// MARK: - Navigation Destinations

enum DailySummaryDestination: Hashable {
    case timeline
    case messaging
}

// MARK: - Preview

#Preview {
    DailySummaryView(date: Date())
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
