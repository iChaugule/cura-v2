import SwiftUI
import Observation

struct FoodLogView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    var log: DailyCareLog
    @State private var selectedMealType: MealType = .breakfast
    @State private var showVoiceNote = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    private func ensureFood() {
        if log.foodLog == nil {
            log.foodLog = FoodLog(
                meals: MealType.allCases.map { MealRecord(mealType: $0) },
                recordedAt: Date())
        }
    }

    private func mealBinding(for type: MealType) -> Binding<MealRecord> {
        Binding(
            get: {
                ensureFood()
                return log.foodLog?.meals.first { $0.mealType == type } ?? MealRecord(mealType: type)
            },
            set: { newVal in
                ensureFood()
                if let idx = log.foodLog?.meals.firstIndex(where: { $0.mealType == type }) {
                    log.foodLog?.meals[idx] = newVal
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mealTabBar
                ScrollView {
                    VStack(spacing: CuraSpacing.lg) {
                        MealDetailView(meal: mealBinding(for: selectedMealType))
                        overallNoteSection
                        VoiceNoteButton { showVoiceNote = true }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, CuraSpacing.md)
                        saveButton
                            .padding(.horizontal, CuraSpacing.md)
                    }
                    .padding(.top, CuraSpacing.md)
                    .padding(.bottom, CuraSpacing.xl)
                }
                .background(Color.curaBackground)
            }
            .background(Color.curaBackground)
            .navigationTitle("Food & Meals")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVoiceNote) { VoiceUpdateView() }
        }
    }

    // MARK: - Meal Tab Bar

    private var mealTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Button(action: { selectedMealType = type }) {
                        VStack(spacing: 4) {
                            Text(type.rawValue)
                                .font(.curaBody)
                                .fontWeight(selectedMealType == type ? .semibold : .regular)
                                .foregroundStyle(selectedMealType == type ? .curaBlue : .secondary)
                                .padding(.horizontal, CuraSpacing.md)
                                .padding(.vertical, CuraSpacing.sm)
                            if selectedMealType == type {
                                Rectangle().fill(Color.curaBlue).frame(height: 2)
                            } else {
                                Rectangle().fill(Color.clear).frame(height: 2)
                            }
                        }
                    }
                    .frame(minWidth: 90, minHeight: 44)
                }
            }
        }
        .background(Color.curaCard)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 2)
    }

    // MARK: - Overall Note

    private var overallNoteSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Overall note (optional)")
                TextField("Any general observations about eating today…",
                          text: Binding(
                            get: { log.foodLog?.overallNote ?? "" },
                            set: { ensureFood(); log.foodLog?.overallNote = $0 }),
                          axis: .vertical)
                    .font(.curaBody).lineLimit(3, reservesSpace: true)
            }
        }
        .padding(.horizontal, CuraSpacing.md)
    }

    // MARK: - Save

    private var saveButton: some View {
        PrimaryButton("Save Food Log", icon: "checkmark.circle.fill", isLoading: isSaving) {
            isSaving = true
            log.foodLog?.recordedAt = Date()
            log.syncState = .syncing
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    log.syncState = .synced
                    isSaving = false
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Meal Detail View

private struct MealDetailView: View {
    @Binding var meal: MealRecord

    var hasChokingAlert: Bool {
        meal.swallowingSafetyObservations.contains(.chokingEpisode)
    }

    var body: some View {
        VStack(spacing: CuraSpacing.md) {
            if hasChokingAlert {
                UrgentBannerView(message: "Choking episode will be flagged as urgent for the family.")
                    .padding(.horizontal, CuraSpacing.md)
            }

            intakeSection
            assistanceSection
            appetiteSection
            swallowingSection
            photoSection
        }
    }

    private var intakeSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("How much did they eat?")
                VStack(spacing: CuraSpacing.sm) {
                    ForEach(MealIntake.allCases, id: \.self) { intake in
                        SelectionCard(title: intake.rawValue, isSelected: meal.intake == intake) {
                            meal.intake = intake
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CuraSpacing.md)
    }

    private var assistanceSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Assistance needed")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(MealAssistance.allCases, id: \.self) { a in
                        ChipButton(title: a.rawValue, isSelected: meal.assistance == a) {
                            meal.assistance = a
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CuraSpacing.md)
    }

    private var appetiteSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Appetite vs. usual")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(AppetiteComparison.allCases, id: \.self) { a in
                        ChipButton(title: a.rawValue, isSelected: meal.appetiteComparison == a) {
                            meal.appetiteComparison = a
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CuraSpacing.md)
    }

    private var swallowingSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                SectionHeader("Swallowing safety", subtitle: "Select all that apply")
                WrapLayout(spacing: CuraSpacing.sm) {
                    ForEach(SwallowingSafety.allCases, id: \.self) { s in
                        let isSelected = meal.swallowingSafetyObservations.contains(s)
                        ChipButton(title: s.rawValue, isSelected: isSelected,
                                   selectedColor: s == .chokingEpisode ? .curaUrgent : .curaBlue) {
                            if isSelected {
                                meal.swallowingSafetyObservations.removeAll { $0 == s }
                            } else {
                                meal.swallowingSafetyObservations.append(s)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CuraSpacing.md)
    }

    private var photoSection: some View {
        CareCard {
            HStack(spacing: CuraSpacing.sm) {
                Image(systemName: "camera.fill")
                    .foregroundStyle(.secondary)
                Button(action: {}) {
                    Text("Add photo of plate")
                        .font(.curaBody).foregroundStyle(.curaBlue)
                }
                .frame(minHeight: 44)
                Spacer()
                Text("Optional · family can see this")
                    .font(.curaCaption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, CuraSpacing.md)
    }
}

#Preview {
    FoodLogView(log: SampleData.emptyCareLog())
        .environment(ServiceContainer())
        .environment(AppSession())
}
