import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class TimelineViewModel {
    var allEntries: [TimelineEntry] = SampleData.timelineEntries
    var selectedCategory: TimelineCategory = .all
    var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var endDate: Date = Date()
    var showDatePicker: Bool = false
    var isLoading: Bool = false
    var error: String? = nil
    var lovedOne: LovedOne = SampleData.lovedOne

    var filteredEntries: [TimelineEntry] {
        allEntries.filter { entry in
            let inDateRange = entry.timestamp >= startDate && entry.timestamp <= endDate
            let inCategory = selectedCategory == .all || entry.category == selectedCategory.observationCategory
            return inDateRange && inCategory
        }
    }

    var entriesByDay: [(date: Date, entries: [TimelineEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        return grouped.keys.sorted(by: >).map { date in
            (date: date, entries: grouped[date]!.sorted { $0.timestamp > $1.timestamp })
        }
    }

    func load(container: ServiceContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            allEntries = try await container.timelineService.entries(for: SampleData.lovedOne.id, from: startDate, to: endDate)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func acknowledge(_ entry: TimelineEntry, container: ServiceContainer) async {
        do {
            try await container.timelineService.acknowledge(entryId: entry.id)
            if let idx = allEntries.firstIndex(where: { $0.id == entry.id }) {
                allEntries[idx].isAcknowledged = true
            }
        } catch { }
    }
}

enum TimelineCategory: String, CaseIterable, Identifiable {
    case all        = "All"
    case meals      = "Meals"
    case hydration  = "Hydration"
    case medication = "Medication"
    case mobility   = "Mobility"
    case mood       = "Mood"
    case safety     = "Safety"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:        return "square.grid.2x2.fill"
        case .meals:      return "fork.knife"
        case .hydration:  return "drop.fill"
        case .medication: return "pill.fill"
        case .mobility:   return "figure.walk"
        case .mood:       return "face.smiling.fill"
        case .safety:     return "shield.fill"
        }
    }

    var observationCategory: ObservationCategory? {
        switch self {
        case .all:        return nil
        case .meals:      return .meal
        case .hydration:  return .hydration
        case .medication: return .medication
        case .mobility:   return .mobility
        case .mood:       return .mood
        case .safety:     return .safety
        }
    }
}

// MARK: - Main View

struct TimelineView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = TimelineViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                Group {
                    if viewModel.isLoading {
                        LoadingView(message: "Loading timeline…")
                    } else if let error = viewModel.error {
                        errorView(error)
                    } else if viewModel.filteredEntries.isEmpty {
                        EmptyStateView(
                            icon: "clock",
                            title: "No entries found",
                            message: "No timeline entries for this category and date range."
                        )
                    } else {
                        timelineList
                    }
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .sheet(isPresented: $viewModel.showDatePicker) { datePickerSheet }
            .task { await viewModel.load(container: container) }
        }
    }

    // MARK: Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(TimelineCategory.allCases) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private func categoryChip(_ category: TimelineCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            viewModel.selectedCategory = category
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.semibold))
                Text(category.rawValue)
                    .font(.careBodyMedium)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(isSelected ? .white : .careAccentBlue)
            .background(isSelected ? Color.careAccentBlue : Color.careAccentBlue.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel("\(category.rawValue) filter. \(isSelected ? "Selected" : "Not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Timeline List

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.entriesByDay, id: \.date) { dayGroup in
                    Section {
                        ForEach(dayGroup.entries) { entry in
                            timelineRow(entry)
                        }
                    } header: {
                        daySectionHeader(dayGroup.date, entries: dayGroup.entries)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: Day Section Header

    private func daySectionHeader(_ date: Date, entries: [TimelineEntry]) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.careSubheading)
                .foregroundStyle(.textPrimary)
            Spacer()
            Text("\(entries.count) entries")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Timeline Row

    private func timelineRow(_ entry: TimelineEntry) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Time bubble
            VStack(spacing: Spacing.xxs) {
                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                    .frame(width: 52, alignment: .center)
                Rectangle()
                    .fill(Color.surfaceRaised)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 52)

            // Entry card
            entryCard(entry)
        }
        .padding(.bottom, Spacing.xs)
    }

    private func entryCard(_ entry: TimelineEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: categoryIcon(entry.category))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(categoryColor(entry.category))
                    .frame(width: 28, height: 28)
                    .background(categoryColor(entry.category).opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(entry.title)
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                    Text("by \(entry.caregiverName)")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                if !entry.isAcknowledged {
                    Circle()
                        .fill(Color.careAccentBlue)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Unread")
                }
            }

            if !entry.detail.isEmpty {
                Text(entry.detail)
                    .font(.careBody)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Spacing.sm) {
                if entry.hasVoiceNote {
                    Button {
                        // Play voice note
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundStyle(.careAccentTeal)
                            Text("Play note")
                                .font(.careCaption)
                                .foregroundStyle(.careAccentTeal)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.careAccentTeal.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Play voice note for this entry")
                }

                if entry.hasPhoto {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.surfaceRaised)
                        .frame(width: 56, height: 44)
                        .overlay {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.textSecondary)
                        }
                        .accessibilityLabel("Photo attached")
                }

                Spacer()

                Button {
                    Task { await viewModel.acknowledge(entry, container: container) }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: entry.isAcknowledged ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(entry.isAcknowledged ? .carePositive : .textSecondary)
                        Text(entry.isAcknowledged ? "Noted" : "Acknowledge")
                            .font(.careCaption)
                            .foregroundStyle(entry.isAcknowledged ? .carePositive : .textSecondary)
                    }
                }
                .frame(minHeight: 44)
                .accessibilityLabel(entry.isAcknowledged ? "Entry acknowledged" : "Acknowledge this entry")
            }

            if entry.followUpRequired {
                Button("Add Follow-Up") {
                    // TODO: open follow-up sheet
                }
                .font(.careBodyMedium)
                .foregroundStyle(.careAttention)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Color.careAttention.opacity(0.1))
                .clipShape(Capsule())
                .frame(minHeight: 44)
                .accessibilityLabel("Add follow-up for this entry")
            }
        }
        .padding(Spacing.md)
        .background(entry.isAcknowledged ? Color.surfaceCard : Color.careAccentBlue.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(entry.isAcknowledged ? Color.clear : Color.careAccentBlue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.careAttention)
            Text("Could not load timeline")
                .font(.careHeading)
            Text(message).font(.careBody).foregroundStyle(.textSecondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.load(container: container) } }
                .buttonStyle(PrimaryButtonStyle(style: .primary))
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Start date", selection: $viewModel.startDate, displayedComponents: .date)
                DatePicker("End date", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: .date)
            }
            .navigationTitle("Date range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.showDatePicker = false
                        Task { await viewModel.load(container: container) }
                    }
                    .accessibilityLabel("Apply date range")
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.showDatePicker = true
            } label: {
                Label("Date range", systemImage: "calendar")
            }
            .accessibilityLabel("Select date range")
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: Helpers

    private func categoryIcon(_ cat: ObservationCategory) -> String {
        switch cat {
        case .meal:       return "fork.knife"
        case .hydration:  return "drop.fill"
        case .medication: return "pill.fill"
        case .mobility:   return "figure.walk"
        case .mood:       return "face.smiling.fill"
        case .safety:     return "shield.fill"
        case .general:    return "note.text"
        }
    }

    private func categoryColor(_ cat: ObservationCategory) -> Color {
        switch cat {
        case .meal:       return .carePositive
        case .hydration:  return .careAccentTeal
        case .medication: return .careAccentBlue
        case .mobility:   return .careCalm
        case .mood:       return .careAttention
        case .safety:     return .careUrgent
        case .general:    return .textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    TimelineView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
