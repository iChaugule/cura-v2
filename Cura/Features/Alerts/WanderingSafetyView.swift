import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class WanderingSafetyViewModel {
    var lovedOne: LovedOne = SampleData.lovedOne
    var riskLevel: WanderingRiskLevel = .elevated
    var showMissingProtocol: Bool = false

    var exitSeekingWindows: [ExitSeekingWindow] = [
        ExitSeekingWindow(startTime: "4:30 PM", endTime: "7:00 PM", frequency: "6 of last 7 days"),
        ExitSeekingWindow(startTime: "6:00 AM", endTime: "7:30 AM", frequency: "3 of last 7 days"),
    ]

    var likelyDestinations: [String] = [
        "Her childhood home in Pune — she often says she needs to \"go home\"",
        "The local temple — she visited every morning for decades",
        "Her sister's house — she frequently asks to see her",
    ]

    var familiarPhrasesBeforeLeaving: [String] = [
        "I need to go home",
        "My mother is waiting for me",
        "I have to cook dinner",
        "I must go to the temple",
    ]

    var redirectionTechniques: [RedirectionTechnique] = [
        RedirectionTechnique(
            title: "Validation + distraction",
            description: "Acknowledge the feeling: \"Let's have some chai first, and then we can go.\" Then engage her with a familiar activity.",
            works: "Often effective in the first 2–3 minutes"
        ),
        RedirectionTechnique(
            title: "Music",
            description: "Playing devotional songs she knows from childhood helps settle exit-seeking behaviour.",
            works: "Effective in ~70% of observed episodes"
        ),
        RedirectionTechnique(
            title: "Photo album",
            description: "Looking at family photos together has a strong calming effect and redirects attention.",
            works: "Effective especially in the late afternoon"
        ),
        RedirectionTechnique(
            title: "Gentle physical engagement",
            description: "Folding laundry or sorting items gives her a purposeful task.",
            works: "Useful when she is mildly agitated"
        ),
    ]

    var emergencyContacts: [EmergencyContact] = [
        EmergencyContact(name: "Sunita Deshpande", role: "Primary family contact", phone: "Need to add"),
        EmergencyContact(name: "Dr. Meera Kulkarni", role: "Geriatric specialist", phone: "Need to add"),
    ]
}

enum WanderingRiskLevel: String {
    case low      = "Low risk"
    case moderate = "Moderate risk"
    case elevated = "Elevated risk"
    case high     = "High risk"

    var icon: String {
        switch self {
        case .low:      return "checkmark.shield.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .elevated: return "exclamationmark.triangle.fill"
        case .high:     return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .low:      return .carePositive
        case .moderate: return .careAttention
        case .elevated: return .careAttention
        case .high:     return .careUrgent
        }
    }
}

struct ExitSeekingWindow: Identifiable {
    let id = UUID()
    let startTime: String
    let endTime: String
    let frequency: String
}

struct RedirectionTechnique: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let works: String
}

struct EmergencyContact: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let phone: String
}

// MARK: - Main View

struct WanderingSafetyView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = WanderingSafetyViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    riskLevelHeader
                    exitSeekingTimesSection
                    likelyDestinationsSection
                    familiarPhrasesSection
                    redirectionSection
                    emergencyContactsSection
                    missingPersonProtocolSection
                    emergencyDisclaimer
                    demoDisclaimer
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Wandering Safety")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showMissingProtocol) { missingPersonSheet }
        }
    }

    // MARK: Risk Level Header

    private var riskLevelHeader: some View {
        VStack(spacing: Spacing.sm) {
            Text("Wandering Safety for \(viewModel.lovedOne.name)")
                .font(.careDisplayMedium)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.sm) {
                Image(systemName: viewModel.riskLevel.icon)
                    .foregroundStyle(viewModel.riskLevel.color)
                    .font(.title3.weight(.semibold))
                Text(viewModel.riskLevel.rawValue)
                    .font(.careBodyMedium)
                    .foregroundStyle(viewModel.riskLevel.color)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(viewModel.riskLevel.color.opacity(0.1))
            .clipShape(Capsule())
            .accessibilityLabel("Risk level: \(viewModel.riskLevel.rawValue)")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    // MARK: Exit-Seeking Times

    private var exitSeekingTimesSection: some View {
        sectionCard(
            icon: "clock.badge.exclamationmark.fill",
            title: "Common exit-seeking times",
            color: .careAttention
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Observe more closely during these windows:")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                ForEach(viewModel.exitSeekingWindows) { window in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.careAttention)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("\(window.startTime) – \(window.endTime)")
                                .font(.careBodyMedium)
                                .foregroundStyle(.textPrimary)
                            Text(window.frequency)
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(Spacing.sm)
                    .background(Color.careAttention.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Exit-seeking window: \(window.startTime) to \(window.endTime), \(window.frequency)")
                }
            }
        }
    }

    // MARK: Likely Destinations

    private var likelyDestinationsSection: some View {
        sectionCard(
            icon: "mappin.and.ellipse.circle.fill",
            title: "Places she may try to visit",
            color: .careAccentBlue
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(viewModel.likelyDestinations, id: \.self) { destination in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.careAccentBlue)
                            .font(.body)
                            .frame(width: 24)
                        Text(destination)
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Familiar Phrases

    private var familiarPhrasesSection: some View {
        sectionCard(
            icon: "quote.bubble.fill",
            title: "Familiar phrases before leaving",
            color: .careCalm
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("She may say these things when preparing to leave:")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                ForEach(viewModel.familiarPhrasesBeforeLeaving, id: \.self) { phrase in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "quote.opening")
                            .font(.caption)
                            .foregroundStyle(.careCalm)
                        Text(phrase)
                            .font(.careBodyMedium)
                            .foregroundStyle(.textPrimary)
                            .italic()
                    }
                }
            }
        }
    }

    // MARK: Redirection Techniques

    private var redirectionSection: some View {
        sectionCard(
            icon: "arrow.triangle.branch",
            title: "Redirection techniques",
            color: .careAccentTeal
        ) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(viewModel.redirectionTechniques) { technique in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.careAccentTeal)
                                .font(.body)
                            Text(technique.title)
                                .font(.careBodyMedium)
                                .foregroundStyle(.textPrimary)
                        }
                        Text(technique.description)
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                                .foregroundStyle(.careAccentTeal)
                            Text(technique.works)
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    .padding(Spacing.sm)
                    .background(Color.careAccentTeal.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(technique.title). \(technique.description). \(technique.works)")
                }
            }
        }
    }

    // MARK: Emergency Contacts

    private var emergencyContactsSection: some View {
        sectionCard(
            icon: "phone.fill.badge.plus",
            title: "Emergency contacts",
            color: .careUrgent
        ) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(viewModel.emergencyContacts) { contact in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.careAccentBlue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(contact.name)
                                .font(.careBodyMedium)
                                .foregroundStyle(.textPrimary)
                            Text(contact.role)
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                            Text(contact.phone)
                                .font(.careBody)
                                .foregroundStyle(.careAccentBlue)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: Missing Person Protocol

    private var missingPersonProtocolSection: some View {
        Button {
            viewModel.showMissingProtocol = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.careUrgent)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("If she is missing right now")
                        .font(.careBodyMedium)
                        .foregroundStyle(.careUrgent)
                    Text("Tap for step-by-step protocol")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.textSecondary)
                    .font(.body)
            }
            .padding(Spacing.md)
            .background(Color.careUrgent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Color.careUrgent.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel("Missing person protocol. Tap to open step-by-step guidance.")
    }

    // MARK: Disclaimer

    private var emergencyDisclaimer: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.textSecondary)
            Text("Cura is not an emergency-response service. Always call emergency services first if you believe someone is in danger.")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
        .padding(Spacing.sm)
        .background(Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private var demoDisclaimer: some View {
        Text("Fictional demonstration data")
            .font(.careCaption)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: Missing Person Sheet

    private var missingPersonSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.careUrgent)
                        VStack(alignment: .leading) {
                            Text("Missing person protocol")
                                .font(.careDisplayMedium)
                            Text("Do these steps in order")
                                .font(.careCaption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    .padding(.top, Spacing.md)

                    let steps: [(String, String)] = [
                        ("Call emergency services", "Call 112 or the relevant number in your area immediately. Do not wait."),
                        ("Contact the current caregiver", "Call the caregiver who was last with \(viewModel.lovedOne.name) and get a description of the last known location."),
                        ("Notify family circle", "Contact everyone in your care circle so they can help search."),
                        ("Open a recent photo", "Find the most recent photo of \(viewModel.lovedOne.name) to share with emergency services. It should show what she was wearing today if possible."),
                        ("Check likely destinations", "Send someone to the places listed above — childhood home, temple, her sister's house — while emergency services are informed."),
                    ]

                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(index == 0 ? Color.careUrgent : Color.careAccentBlue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text("\(index + 1)")
                                    .font(.careBodyMedium)
                                    .foregroundStyle(index == 0 ? .white : .careAccentBlue)
                            }
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(step.0)
                                    .font(.careBodyMedium)
                                    .foregroundStyle(.textPrimary)
                                Text(step.1)
                                    .font(.careBody)
                                    .foregroundStyle(.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(Spacing.sm)
                        .background(index == 0 ? Color.careUrgent.opacity(0.08) : Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(index == 0 ? Color.careUrgent.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Step \(index + 1): \(step.0). \(step.1)")
                    }

                    Text("Cura is not an emergency-response service. This guidance does not replace emergency services.")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.showMissingProtocol = false }
                        .accessibilityLabel("Close missing person protocol")
                }
            }
        }
    }

    // MARK: Helper

    @ViewBuilder
    private func sectionCard<Content: View>(
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
}

// MARK: - Preview

#Preview {
    WanderingSafetyView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
