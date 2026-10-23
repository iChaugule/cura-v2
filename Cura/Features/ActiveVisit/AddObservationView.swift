import SwiftUI
import Observation

@MainActor
@Observable
final class AddObservationViewModel {
    var category: ObservationCategory = .moodBehavior
    var selectedObservations: Set<String> = []
    var time: Date = Date()
    var severity: AlertTier = .informational
    var followUpRequired: Bool = false
    var note: String = ""
    var isSaving: Bool = false
    var isBackdated: Bool = false

    func observationOptions(for category: ObservationCategory) -> [String] {
        switch category {
        case .orientation:
            return ["Recognised caregiver", "Recognised family member", "Correctly oriented to place",
                    "Confused about location", "Asked to go home", "Repeated questions",
                    "Appeared more confused than usual", "Unable to assess orientation"]
        case .moodBehavior:
            return ["Calm and settled", "Cheerful", "Anxious or worried", "Agitated",
                    "Restless / pacing", "Tearful", "Withdrawn", "Resistant to care",
                    "Calling for family", "Suspicious"]
        case .communication:
            return ["Communicating normally", "Difficulty finding words", "Using short phrases",
                    "Mainly gestures", "Less responsive than usual", "Non-verbal"]
        case .dailyFunctioning:
            return ["Ate well", "Poor appetite", "Good hydration", "Refused fluids",
                    "Walked independently", "Needed mobility assist", "Rested most of the day",
                    "Participated in activity"]
        case .safety:
            return ["Near-fall", "Fall — no injury", "Fall — possible injury",
                    "Choking episode", "Skin concern observed", "Wandering behaviour",
                    "Unusual fatigue", "Unexplained bruise or mark"]
        }
    }

    func save() async {
        isSaving = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isSaving = false
    }
}

struct AddObservationView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = AddObservationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.lg) {
                    categoryPicker
                    timePicker
                    observationGrid
                    severityPicker
                    noteField
                    followUpToggle
                    saveButton
                }
                .padding(CuraSpacing.md)
                .padding(.bottom, CuraSpacing.xl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Add Observation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var categoryPicker: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Category")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CuraSpacing.sm) {
                        ForEach(ObservationCategory.allCases, id: \.self) { cat in
                            ChipButton(title: cat.rawValue, isSelected: viewModel.category == cat) {
                                viewModel.category = cat
                                viewModel.selectedObservations = []
                            }
                        }
                    }
                }
            }
        }
    }

    private var timePicker: some View {
        CareCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SectionHeader("Time")
                    if viewModel.isBackdated {
                        StatusBadge("Recorded later", color: .curaWarning)
                    }
                }
                Spacer()
                DatePicker("", selection: $viewModel.time,
                           in: Calendar.current.date(byAdding: .hour, value: -12, to: Date())!...Date(),
                           displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .onChange(of: viewModel.time) { _, newVal in
                        viewModel.isBackdated = newVal.timeIntervalSinceNow < -60
                    }
            }
        }
    }

    private var observationGrid: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("What did you observe?", subtitle: "Select all that apply")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(viewModel.observationOptions(for: viewModel.category), id: \.self) { obs in
                        let isSelected = viewModel.selectedObservations.contains(obs)
                        let isSafety = obs.contains("injury") || obs.contains("Fall") || obs.contains("Choking")
                        ChipButton(title: obs, isSelected: isSelected, selectedColor: isSafety ? .curaUrgent : .curaBlue) {
                            if isSelected {
                                viewModel.selectedObservations.remove(obs)
                            } else {
                                viewModel.selectedObservations.insert(obs)
                                if isSafety { viewModel.severity = .urgent; viewModel.followUpRequired = true }
                            }
                        }
                    }
                }
            }
        }
    }

    private var severityPicker: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Severity")
                HStack(spacing: CuraSpacing.sm) {
                    ForEach([AlertTier.informational, .monitorClosely, .contactCare, .urgent], id: \.self) { tier in
                        let label: String = {
                            switch tier {
                            case .informational:  return "Routine"
                            case .monitorClosely: return "Notable"
                            case .contactCare:    return "Concern"
                            case .urgent:         return "Urgent"
                            }
                        }()
                        let color: Color = {
                            switch tier {
                            case .informational:  return .curaBlue
                            case .monitorClosely: return .curaWarning
                            case .contactCare:    return .curaWarning
                            case .urgent:         return .curaUrgent
                            }
                        }()
                        ChipButton(title: label, isSelected: viewModel.severity == tier, selectedColor: color) {
                            viewModel.severity = tier
                        }
                    }
                }
            }
        }
    }

    private var noteField: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Note (optional)")
                TextField("Describe what you observed…", text: $viewModel.note, axis: .vertical)
                    .font(.curaBody)
                    .lineLimit(3, reservesSpace: true)
            }
        }
    }

    private var followUpToggle: some View {
        CareCard {
            Toggle(isOn: $viewModel.followUpRequired) {
                Label("Follow-up required", systemImage: "bell.fill")
                    .font(.curaBody)
            }
            .tint(.curaBlue)
            .frame(minHeight: 44)
        }
    }

    private var saveButton: some View {
        PrimaryButton(
            "Save Observation",
            icon: "checkmark.circle.fill",
            isLoading: viewModel.isSaving
        ) {
            Task {
                await viewModel.save()
                dismiss()
            }
        }
        .disabled(viewModel.selectedObservations.isEmpty)
        .opacity(viewModel.selectedObservations.isEmpty ? 0.5 : 1)
    }
}

#Preview {
    AddObservationView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
