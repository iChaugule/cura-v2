import SwiftUI
import LocalAuthentication

// MARK: - ViewModel

@MainActor
@Observable
final class MemoryCarePassportViewModel {
    var passport: MemoryCarePassport = SampleData.passport
    var lovedOne: LovedOne = SampleData.lovedOne
    var expandedSections: Set<PassportSection> = []
    var unlockedSections: Set<PassportSection> = []
    var editingSection: PassportSection? = nil
    var privacyLevel: PassportPrivacyLevel = .caregivers
    var isLoading: Bool = false

    var overallCompletion: Double {
        let completed = PassportSection.allCases.filter { sectionCompletion($0) > 0 }.count
        return Double(completed) / Double(PassportSection.allCases.count)
    }

    func sectionCompletion(_ section: PassportSection) -> Double {
        switch section {
        case .about:              return !passport.preferredName.isEmpty ? 1 : 0
        case .diagnosisContext:   return passport.cognitiveStage != nil ? 1 : 0
        case .communication:      return passport.bestCommunicationTips != nil ? 1 : 0
        case .familiarPeople:     return !passport.importantPeople.isEmpty ? 1 : 0
        case .dailyRoutine:       return !passport.routineNotes.isEmpty ? 1 : 0
        case .comfortPersonality: return !passport.likesAndComforts.isEmpty ? 1 : 0
        case .behaviorPatterns:   return passport.distressTriggers != nil ? 1 : 0
        case .mobilityPersonalCare: return passport.walkingAbility != nil ? 1 : 0
        case .foodHydration:      return passport.preferredFoods != nil ? 1 : 0
        case .medications:        return passport.medicationScheduleSummary != nil ? 1 : 0
        case .safety:             return !passport.safetyNotes.isEmpty ? 1 : 0
        case .emergencyContacts:  return passport.emergencyContacts?.isEmpty == false ? 1 : 0
        }
    }

    func toggleExpanded(_ section: PassportSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    func authenticateAndUnlock(_ section: PassportSection) async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            unlockedSections.insert(section)
            return
        }
        do {
            let reason = "View sensitive care information for \(lovedOne.name)"
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success { unlockedSections.insert(section) }
        } catch {
            // Authentication failed or cancelled — do nothing
        }
    }
}

// MARK: - Section Enum

enum PassportSection: String, CaseIterable, Identifiable {
    case about              = "About"
    case diagnosisContext   = "Diagnosis & Context"
    case communication      = "Communication"
    case familiarPeople     = "Familiar People & Places"
    case dailyRoutine       = "Daily Routine"
    case comfortPersonality = "Comfort & Personality"
    case behaviorPatterns   = "Behavior & Patterns"
    case mobilityPersonalCare = "Mobility & Personal Care"
    case foodHydration      = "Food & Hydration"
    case medications        = "Medications"
    case safety             = "Safety"
    case emergencyContacts  = "Emergency Contacts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .about:               return "person.fill"
        case .diagnosisContext:    return "brain.head.profile"
        case .communication:       return "bubble.left.and.bubble.right.fill"
        case .familiarPeople:      return "figure.2.arms.open"
        case .dailyRoutine:        return "sun.max.fill"
        case .comfortPersonality:  return "heart.fill"
        case .behaviorPatterns:    return "chart.xyaxis.line"
        case .mobilityPersonalCare: return "figure.walk"
        case .foodHydration:       return "fork.knife"
        case .medications:         return "pill.fill"
        case .safety:              return "lock.shield.fill"
        case .emergencyContacts:   return "phone.fill.badge.plus"
        }
    }

    var isBiometricGated: Bool {
        switch self {
        case .safety, .medications, .emergencyContacts: return true
        default: return false
        }
    }
}

enum PassportPrivacyLevel: String, CaseIterable {
    case caregivers  = "Visible to caregivers"
    case visitOnly   = "Visit-only access"
    case familyOnly  = "Family only"

    var icon: String {
        switch self {
        case .caregivers:  return "person.2.fill"
        case .visitOnly:   return "clock.badge.checkmark.fill"
        case .familyOnly:  return "house.fill"
        }
    }
}

// MARK: - Main View

struct MemoryCarePassportView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = MemoryCarePassportViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    helpMeFeelSafeCard
                    privacyControlChip
                    sectionsGroup
                    demoDisclaimer
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Memory Care Passport")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    name: viewModel.lovedOne.name,
                    url: viewModel.lovedOne.avatarUrl,
                    size: 96
                )
                completionRingOverlay
                    .offset(x: 8, y: 8)
            }
            VStack(spacing: Spacing.xxs) {
                Text(viewModel.lovedOne.name)
                    .font(.careDisplayMedium)
                    .foregroundStyle(.textPrimary)
                Text("Memory Care Passport")
                    .font(.careSubheading)
                    .foregroundStyle(.careAccentTeal)
                completionLabel
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
    }

    private var completionRingOverlay: some View {
        ZStack {
            Circle()
                .stroke(Color.surfaceRaised, lineWidth: 4)
                .frame(width: 36, height: 36)
            Circle()
                .trim(from: 0, to: viewModel.overallCompletion)
                .stroke(Color.careAccentTeal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)
            Text("\(Int(viewModel.overallCompletion * 100))%")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.careAccentTeal)
        }
    }

    private var completionLabel: some View {
        HStack(spacing: Spacing.xxs) {
            ProgressView(value: viewModel.overallCompletion)
                .tint(.careAccentTeal)
                .frame(width: 120)
            Text("\(Int(viewModel.overallCompletion * 100))% complete")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
    }

    // MARK: Help Me Feel Safe Card

    private var helpMeFeelSafeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("Help Me Feel Safe")
                    .font(.careHeading)
                    .foregroundStyle(.white)
            }
            Text("When \(viewModel.lovedOne.name) feels anxious, these phrases help:")
                .font(.careBody)
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(viewModel.passport.calmingPhrases.prefix(3), id: \.self) { phrase in
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(phrase)
                            .font(.careBodyMedium)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            LinearGradient(
                colors: [Color.careAccentTeal, Color.careAccentBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Help Me Feel Safe. Calming phrases for \(viewModel.lovedOne.name): \(viewModel.passport.calmingPhrases.prefix(3).joined(separator: ". "))")
    }

    // MARK: Privacy Control

    private var privacyControlChip: some View {
        HStack {
            Menu {
                ForEach(PassportPrivacyLevel.allCases, id: \.self) { level in
                    Button {
                        viewModel.privacyLevel = level
                    } label: {
                        Label(level.rawValue, systemImage: level.icon)
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: viewModel.privacyLevel.icon)
                        .font(.caption.weight(.semibold))
                    Text(viewModel.privacyLevel.rawValue)
                        .font(.careBodyMedium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.careAccentBlue)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.careAccentBlue.opacity(0.1))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Passport visibility: \(viewModel.privacyLevel.rawValue). Tap to change.")
            Spacer()
        }
    }

    // MARK: Sections

    private var sectionsGroup: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(PassportSection.allCases) { section in
                passportSectionCard(section)
            }
        }
    }

    @ViewBuilder
    private func passportSectionCard(_ section: PassportSection) -> some View {
        let isExpanded = viewModel.expandedSections.contains(section)
        let isLocked = section.isBiometricGated && !viewModel.unlockedSections.contains(section)
        let completion = viewModel.sectionCompletion(section)

        CareCard {
            VStack(spacing: 0) {
                // Header row
                Button {
                    if isLocked {
                        Task { await viewModel.authenticateAndUnlock(section) }
                    } else {
                        viewModel.toggleExpanded(section)
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: section.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.careAccentBlue)
                            .frame(width: 28, height: 28)
                        Text(section.rawValue)
                            .font(.careBodyMedium)
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.textSecondary)
                                .font(.caption)
                        } else {
                            sectionCompletionRing(completion)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    .padding(Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("\(section.rawValue) section. \(isLocked ? "Locked — tap to authenticate." : (isExpanded ? "Expanded" : "Collapsed")). \(Int(completion * 100))% complete.")

                if isExpanded && !isLocked {
                    Divider().padding(.horizontal, Spacing.md)
                    sectionContent(section)
                        .padding(Spacing.md)
                    HStack {
                        Spacer()
                        Button("Edit") {
                            viewModel.editingSection = section
                        }
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.sm)
                        .accessibilityLabel("Edit \(section.rawValue)")
                    }
                }
            }
        }
    }

    private func sectionCompletionRing(_ value: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.surfaceRaised, lineWidth: 3)
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    value > 0.7 ? Color.carePositive : (value > 0.3 ? Color.careAttention : Color.careUrgent),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }

    @ViewBuilder
    private func sectionContent(_ section: PassportSection) -> some View {
        switch section {
        case .about:
            passportFieldGroup([
                ("Full name", viewModel.passport.fullName),
                ("Preferred name", viewModel.passport.preferredName),
                ("Date of birth", viewModel.passport.dateOfBirth),
                ("Diagnosis", viewModel.passport.primaryDiagnosis),
                ("Years since diagnosis", viewModel.passport.yearsSinceDiagnosis),
            ])
        case .diagnosisContext:
            passportFieldGroup([
                ("Current stage", viewModel.passport.cognitiveStage),
                ("Primary challenges", viewModel.passport.primaryChallenges),
                ("Specialist", viewModel.passport.specialistName),
                ("Last assessment", viewModel.passport.lastAssessmentDate),
            ])
        case .communication:
            passportFieldGroup([
                ("Primary language", viewModel.passport.primaryLanguage),
                ("Comprehension level", viewModel.passport.comprehensionLevel),
                ("Best communication", viewModel.passport.bestCommunicationTips),
                ("Avoid", viewModel.passport.communicationAvoid),
            ])
        case .familiarPeople:
            passportFieldGroup([
                ("Family members", viewModel.passport.familyMembersDescription),
                ("Important places", viewModel.passport.importantPlaces),
                ("Former home", viewModel.passport.formerHomeDescription),
            ])
        case .dailyRoutine:
            passportFieldGroup([
                ("Wake time", viewModel.passport.typicalWakeTime),
                ("Morning routine", viewModel.passport.morningRoutineSummary),
                ("Afternoon preferences", viewModel.passport.afternoonPreferences),
                ("Bedtime", viewModel.passport.typicalBedtime),
                ("Evening routine", viewModel.passport.eveningRoutineSummary),
            ])
        case .comfortPersonality:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                passportFieldGroup([
                    ("Personality", viewModel.passport.personalityDescription),
                    ("What brings joy", viewModel.passport.joyTriggers),
                    ("Comforting items", viewModel.passport.comfortingItems),
                ])
                Text("Calming phrases")
                    .font(.careBodyMedium)
                    .foregroundStyle(.textSecondary)
                ForEach(viewModel.passport.calmingPhrases, id: \.self) { phrase in
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "quote.opening")
                            .font(.caption)
                            .foregroundStyle(.careAccentTeal)
                        Text(phrase)
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
        case .behaviorPatterns:
            passportFieldGroup([
                ("Triggers for distress", viewModel.passport.distressTriggers),
                ("Early warning signs", viewModel.passport.earlyWarningSigns),
                ("De-escalation", viewModel.passport.deEscalationStrategies),
                ("Sundowning pattern", viewModel.passport.sundowingPattern),
            ])
        case .mobilityPersonalCare:
            passportFieldGroup([
                ("Walking ability", viewModel.passport.walkingAbility),
                ("Assistive devices", viewModel.passport.assistiveDevices),
                ("Bathing preferences", viewModel.passport.bathingPreferences),
                ("Dressing preferences", viewModel.passport.dressingPreferences),
                ("Continence", viewModel.passport.continenceNotes),
            ])
        case .foodHydration:
            passportFieldGroup([
                ("Preferred foods", viewModel.passport.preferredFoods),
                ("Avoided foods", viewModel.passport.avoidedFoods),
                ("Allergies", viewModel.passport.foodAllergies),
                ("Fluid preferences", viewModel.passport.fluidPreferences),
                ("Texture needs", viewModel.passport.textureNeeds),
                ("Eating assistance", viewModel.passport.eatingAssistanceNotes),
            ])
        case .medications:
            passportFieldGroup([
                ("Medication schedule", viewModel.passport.medicationScheduleSummary),
                ("Administration notes", viewModel.passport.medicationAdministrationNotes),
                ("Side effects to watch", viewModel.passport.medicationSideEffectsToWatch),
            ])
        case .safety:
            passportFieldGroup([
                ("Wandering risk", viewModel.passport.wanderingRiskLevel),
                ("Home safety notes", viewModel.passport.homeSafetyNotes),
                ("Locked areas", viewModel.passport.lockedAreaNotes),
                ("Emergency word", viewModel.passport.emergencyWord),
            ])
        case .emergencyContacts:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(viewModel.passport.emergencyContacts ?? [], id: \.name) { contact in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.careAccentBlue)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(contact.name).font(.careBodyMedium).foregroundStyle(.textPrimary)
                            Text(contact.relationship).font(.careCaption).foregroundStyle(.textSecondary)
                            Text(contact.phone).font(.careBody).foregroundStyle(.careAccentBlue)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func passportFieldGroup(_ fields: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(fields, id: \.0) { label, value in
                if let value, !value.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(label)
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                            .textCase(.uppercase)
                        Text(value)
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: Disclaimer

    private var demoDisclaimer: some View {
        Text("Fictional demonstration data")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.sm)
    }
}

// MARK: - Avatar View

private struct AvatarView: View {
    let name: String
    let url: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.careAccentBlue.opacity(0.15))
            if let url {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { initials }
                    .clipShape(Circle())
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
    }

    private var initials: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.careAccentBlue)
    }
}

// MARK: - Preview

#Preview {
    MemoryCarePassportView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
