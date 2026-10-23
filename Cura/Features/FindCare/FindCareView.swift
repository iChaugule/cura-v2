import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class FindCareViewModel {
    var searchText: String = ""
    var caregivers: [Caregiver] = SampleData.caregivers
    var recommendedCaregivers: [CaregiverMatch] = []
    var isLoading: Bool = false
    var error: String? = nil
    var showFilters: Bool = false
    var filters: CaregiverFilters = CaregiverFilters()
    var lovedOne: LovedOne = SampleData.lovedOne

    var filteredCaregivers: [Caregiver] {
        var result = caregivers
        if !searchText.isEmpty {
            result = result.filter { c in
                c.name.localizedCaseInsensitiveContains(searchText) ||
                c.city.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    func load(container: ServiceContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await container.caregiverService.searchCaregivers()
            caregivers = all
            recommendedCaregivers = all.prefix(3).map { CaregiverMatch(caregiver: $0, matchReason: "Experienced with dementia care and speaks Marathi") }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CaregiverFilters: Equatable {
    var city: String = ""
    var date: Date = Date()
    var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var endTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    var languages: Set<LanguageCode> = []
    var preferredGender: String = "No preference"
    var minRate: Double = 20
    var maxRate: Double = 100
    var minYearsExperience: Int = 0
    var specialties: Set<String> = []
    var dementiaTrainingRequired: Bool = false
}

struct CaregiverMatch: Identifiable {
    let id = UUID()
    let caregiver: Caregiver
    let matchReason: String
}

// MARK: - Main View

struct FindCareView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = FindCareViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var selectedCaregiver: Caregiver? = nil

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "Finding caregivers…")
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    caregiverListContent
                }
            }
            .navigationTitle("Find Care")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search by name or city")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showFilters = true
                    } label: {
                        Label("Filters", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Open search filters")
                }
            }
            .sheet(isPresented: $viewModel.showFilters) {
                FilterSheet(filters: $viewModel.filters, onApply: {
                    viewModel.showFilters = false
                    Task { await viewModel.load(container: container) }
                })
            }
            .navigationDestination(for: Caregiver.self) { caregiver in
                CaregiverProfileView(caregiver: caregiver)
            }
            .task { await viewModel.load(container: container) }
        }
    }

    // MARK: List Content

    private var caregiverListContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg, pinnedViews: []) {
                if !viewModel.recommendedCaregivers.isEmpty && viewModel.searchText.isEmpty {
                    recommendedSection
                }
                allCaregiversSection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Recommended for \(viewModel.lovedOne.name)")
            ForEach(viewModel.recommendedCaregivers) { match in
                CaregiverCard(
                    caregiver: match.caregiver,
                    matchReason: match.matchReason,
                    onViewProfile: { navigationPath.append(match.caregiver) },
                    onBook: { selectedCaregiver = match.caregiver }
                )
            }
        }
    }

    private var allCaregiversSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                title: viewModel.searchText.isEmpty ? "All caregivers" : "Search results",
                subtitle: "\(viewModel.filteredCaregivers.count) found"
            )
            if viewModel.filteredCaregivers.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No caregivers found",
                    message: "Try adjusting your filters or search terms."
                )
            } else {
                ForEach(viewModel.filteredCaregivers) { caregiver in
                    CaregiverCard(
                        caregiver: caregiver,
                        matchReason: nil,
                        onViewProfile: { navigationPath.append(caregiver) },
                        onBook: { selectedCaregiver = caregiver }
                    )
                }
            }
        }
    }

    // MARK: Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.careAttention)
            Text("Could not load caregivers")
                .font(.careHeading)
                .foregroundStyle(.textPrimary)
            Text(message)
                .font(.careBody)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await viewModel.load(container: container) }
            }
            .buttonStyle(PrimaryButtonStyle(style: .primary))
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Caregiver Card

struct CaregiverCard: View {
    let caregiver: Caregiver
    let matchReason: String?
    let onViewProfile: () -> Void
    let onBook: () -> Void

    var body: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header row
                HStack(alignment: .top, spacing: Spacing.sm) {
                    caregiverAvatar
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(caregiver.firstName)
                            .font(.careHeading)
                            .foregroundStyle(.textPrimary)
                        Text(caregiver.city)
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                        ratingRow
                    }
                    Spacer()
                    rateChip
                }

                // Language chips
                languageChips

                // Specialty badges
                specialtyBadges

                // Match reason
                if let reason = matchReason {
                    matchReasonBanner(reason)
                }

                Divider()

                // Action buttons
                HStack(spacing: Spacing.sm) {
                    Button("View Profile", action: onViewProfile)
                        .buttonStyle(PrimaryButtonStyle(style: .secondary))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("View \(caregiver.firstName)'s full profile")

                    Button("Book Now", action: onBook)
                        .buttonStyle(PrimaryButtonStyle(style: .primary))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Book \(caregiver.firstName)")
                }
            }
            .padding(Spacing.md)
        }
    }

    private var caregiverAvatar: some View {
        ZStack {
            Circle().fill(Color.careAccentTeal.opacity(0.2))
            if let url = caregiver.photoUrl {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                    initials
                }
                .clipShape(Circle())
            } else {
                initials
            }
        }
        .frame(width: 56, height: 56)
    }

    private var initials: some View {
        Text(String(caregiver.firstName.prefix(1)))
            .font(.title3.weight(.semibold))
            .foregroundStyle(.careAccentTeal)
    }

    private var ratingRow: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "star.fill")
                .foregroundStyle(.careAttention)
                .font(.caption)
            Text(String(format: "%.1f", caregiver.rating))
                .font(.careCaption)
                .foregroundStyle(.textPrimary)
            Text("(\(caregiver.reviewCount))")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
            Text("· \(caregiver.yearsExperience) yrs exp")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
    }

    private var rateChip: some View {
        VStack(spacing: Spacing.xxs) {
            Text("$\(Int(caregiver.hourlyRate))")
                .font(.careHeading)
                .foregroundStyle(.careAccentBlue)
            Text("per hour")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
    }

    private var languageChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(caregiver.languages, id: \.self) { lang in
                    Text(lang.displayName)
                        .font(.careCaption)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.careAccentBlue.opacity(0.1))
                        .foregroundStyle(.careAccentBlue)
                        .clipShape(Capsule())
                }
            }
        }
        .accessibilityLabel("Languages: \(caregiver.languages.map(\.displayName).joined(separator: ", "))")
    }

    private var specialtyBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(caregiver.specialties, id: \.self) { specialty in
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(specialty)
                            .font(.careCaption)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.carePositive.opacity(0.12))
                    .foregroundStyle(.carePositive)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func matchReasonBanner(_ reason: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.careAccentTeal)
            Text(reason)
                .font(.careCaption)
                .foregroundStyle(.careAccentTeal)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.careAccentTeal.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Binding var filters: CaregiverFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Location & Schedule") {
                    TextField("City", text: $filters.city)
                    DatePicker("Date", selection: $filters.date, displayedComponents: .date)
                    DatePicker("Start time", selection: $filters.startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End time", selection: $filters.endTime, displayedComponents: .hourAndMinute)
                }
                Section("Caregiver Preferences") {
                    Picker("Gender preference", selection: $filters.preferredGender) {
                        Text("No preference").tag("No preference")
                        Text("Female").tag("Female")
                        Text("Male").tag("Male")
                        Text("Non-binary").tag("Non-binary")
                    }
                    Toggle("Dementia training required", isOn: $filters.dementiaTrainingRequired)
                    Stepper("Min. \(filters.minYearsExperience) years experience", value: $filters.minYearsExperience, in: 0...20)
                }
                Section("Rate") {
                    HStack {
                        Text("$\(Int(filters.minRate)) – $\(Int(filters.maxRate))/hr")
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                        Spacer()
                    }
                    RangeSlider(low: $filters.minRate, high: $filters.maxRate, range: 20...150)
                        .frame(height: 44)
                        .accessibilityLabel("Hourly rate range: $\(Int(filters.minRate)) to $\(Int(filters.maxRate))")
                }
                Section("Languages") {
                    ForEach(LanguageCode.allCases, id: \.self) { lang in
                        Button {
                            if filters.languages.contains(lang) {
                                filters.languages.remove(lang)
                            } else {
                                filters.languages.insert(lang)
                            }
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .font(.careBody)
                                    .foregroundStyle(.textPrimary)
                                Spacer()
                                if filters.languages.contains(lang) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.careAccentBlue)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("\(lang.displayName). \(filters.languages.contains(lang) ? "Selected" : "Not selected")")
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel filters")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply() }
                        .font(.careBodyMedium)
                        .accessibilityLabel("Apply filters")
                }
            }
        }
    }
}

// MARK: - Simple Range Slider placeholder

private struct RangeSlider: View {
    @Binding var low: Double
    @Binding var high: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Slider(value: $low, in: range.lowerBound...high - 10, step: 5)
                .tint(.careAccentBlue)
            Slider(value: $high, in: low + 10...range.upperBound, step: 5)
                .tint(.careAccentBlue)
        }
    }
}

// MARK: - Preview

#Preview {
    FindCareView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
