import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class FamilySettingsViewModel {
    var user: User = SampleData.familyUser
    var lovedOnes: [LovedOne] = [SampleData.lovedOne]
    var showDeleteConfirmation: Bool = false
    var showDeleteConfirmed: Bool = false

    // Notification Preferences
    var notifyUrgentAlerts: Bool     = true
    var notifyMonitorAlerts: Bool    = true
    var notifyInfoAlerts: Bool       = false
    var notifyNewMessages: Bool      = true
    var notifyTimelineUpdates: Bool  = true
    var notifyBookingChanges: Bool   = true
    var notifyWeeklySummary: Bool    = true
    var notifyLateArrival: Bool      = true

    // Language
    var selectedLanguage: LanguageCode   = .english
    var serverTranslationConsent: Bool   = true

    // Accessibility
    var useLargeText: Bool           = false
    var useReduceMotion: Bool        = false
    var useHighContrast: Bool        = false

    func deleteAccount(container: ServiceContainer) async {
        do {
            try await container.authService.deleteAccount()
            showDeleteConfirmed = true
        } catch { }
    }
}

// MARK: - Main View

struct FamilySettingsView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = FamilySettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                profileSection
                lovedOnesSection
                familyCircleSection
                notificationSection
                languageSection
                accessibilitySection
                paymentSection
                privacySection
                documentsSection
                legalSection
                deleteSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Profile Section

    private var profileSection: some View {
        Section {
            HStack(spacing: Spacing.md) {
                avatarView
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(viewModel.user.name)
                        .font(.careDisplayMedium)
                        .foregroundStyle(.textPrimary)
                    Text(viewModel.user.email)
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                    Text(viewModel.user.role.displayName)
                        .font(.careCaption)
                        .foregroundStyle(.careAccentBlue)
                }
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 72)
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.careAccentBlue.opacity(0.2))
            Text(String(viewModel.user.name.prefix(1)))
                .font(.title.weight(.semibold))
                .foregroundStyle(.careAccentBlue)
        }
        .frame(width: 64, height: 64)
    }

    // MARK: Loved Ones Section

    private var lovedOnesSection: some View {
        Section("Loved Ones") {
            ForEach(viewModel.lovedOnes) { lovedOne in
                NavigationLink {
                    MemoryCarePassportView()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        ZStack {
                            Circle().fill(Color.careAccentTeal.opacity(0.2))
                            Text(String(lovedOne.name.prefix(1)))
                                .font(.headline)
                                .foregroundStyle(.careAccentTeal)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(lovedOne.name).font(.careBodyMedium)
                            Text("Memory Care Passport").font(.careCaption).foregroundStyle(.textSecondary)
                        }
                    }
                }
                .frame(minHeight: 56)
            }
            NavigationLink("Add a loved one") {
                Text("Add loved one form — coming soon")
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Family Circle Section

    private var familyCircleSection: some View {
        Section("Family Care Circle") {
            NavigationLink {
                FamilyCircleView()
            } label: {
                settingsRow(icon: "person.3.fill", label: "Manage family circle", color: .careAccentBlue)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Notification Section

    private var notificationSection: some View {
        Section {
            notificationToggle("Urgent alerts", isOn: $viewModel.notifyUrgentAlerts, warnIfOff: true)
            notificationToggle("Monitor closely alerts", isOn: $viewModel.notifyMonitorAlerts, warnIfOff: false)
            notificationToggle("Informational alerts", isOn: $viewModel.notifyInfoAlerts, warnIfOff: false)
            notificationToggle("New messages", isOn: $viewModel.notifyNewMessages, warnIfOff: false)
            notificationToggle("Timeline updates", isOn: $viewModel.notifyTimelineUpdates, warnIfOff: false)
            notificationToggle("Booking changes", isOn: $viewModel.notifyBookingChanges, warnIfOff: false)
            notificationToggle("Weekly summary", isOn: $viewModel.notifyWeeklySummary, warnIfOff: false)
            notificationToggle("Late caregiver arrival", isOn: $viewModel.notifyLateArrival, warnIfOff: false)
        } header: {
            Text("Notification Preferences")
        } footer: {
            if !viewModel.notifyUrgentAlerts {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.careUrgent)
                    Text("Turning off urgent alerts means you may not be notified in time-sensitive situations.")
                        .foregroundStyle(.careUrgent)
                }
            }
        }
    }

    private func notificationToggle(_ label: String, isOn: Binding<Bool>, warnIfOff: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label).font(.careBody).foregroundStyle(.textPrimary)
                if warnIfOff && !isOn.wrappedValue {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.careUrgent)
                        Text("Recommended to keep on").font(.careCaption).foregroundStyle(.careUrgent)
                    }
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(.careAccentBlue)
                .labelsHidden()
        }
        .frame(minHeight: 44)
        .accessibilityLabel("\(label): \(isOn.wrappedValue ? "On" : "Off")\(warnIfOff && !isOn.wrappedValue ? ". Warning: recommended to keep on." : "")")
    }

    // MARK: Language & Translation Section

    private var languageSection: some View {
        Section {
            Picker("App language", selection: $viewModel.selectedLanguage) {
                ForEach(LanguageCode.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.navigationLink)
            .frame(minHeight: 44)
            .accessibilityLabel("App language: \(viewModel.selectedLanguage.displayName)")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle("Translate caregiver messages", isOn: $viewModel.serverTranslationConsent)
                    .tint(.careAccentBlue)
                    .font(.careBody)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Translate caregiver messages on the server: \(viewModel.serverTranslationConsent ? "On" : "Off")")
                Text("Messages written by caregivers in other languages will be translated on Cura's servers before being shown to you. The original text is always available.")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
        } header: {
            Text("Language & Translation")
        }
    }

    // MARK: Accessibility

    private var accessibilitySection: some View {
        Section("Accessibility") {
            Toggle("Larger text", isOn: $viewModel.useLargeText)
                .tint(.careAccentBlue)
                .frame(minHeight: 44)
                .accessibilityLabel("Larger text: \(viewModel.useLargeText ? "On" : "Off")")
            Toggle("Reduce motion", isOn: $viewModel.useReduceMotion)
                .tint(.careAccentBlue)
                .frame(minHeight: 44)
                .accessibilityLabel("Reduce motion: \(viewModel.useReduceMotion ? "On" : "Off")")
            Toggle("Increase contrast", isOn: $viewModel.useHighContrast)
                .tint(.careAccentBlue)
                .frame(minHeight: 44)
                .accessibilityLabel("Increase contrast: \(viewModel.useHighContrast ? "On" : "Off")")
        }
    }

    // MARK: Payment Methods

    private var paymentSection: some View {
        Section("Payment Methods") {
            NavigationLink {
                placeholderView("Payment Methods", "Manage your saved payment methods here.")
            } label: {
                settingsRow(icon: "creditcard.fill", label: "Manage payment methods", color: .careAccentTeal)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Privacy Controls

    private var privacySection: some View {
        Section("Privacy Controls") {
            NavigationLink {
                placeholderView("Privacy Controls", "Data sharing and deletion options.")
            } label: {
                settingsRow(icon: "lock.shield.fill", label: "Privacy & data controls", color: .careCalm)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Documents

    private var documentsSection: some View {
        Section("Documents") {
            NavigationLink {
                placeholderView("Documents", "Care-related documents stored securely.")
            } label: {
                settingsRow(icon: "doc.fill", label: "Care documents", color: .careAccentBlue)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Legal

    private var legalSection: some View {
        Section("Terms & Privacy") {
            NavigationLink {
                placeholderView("Terms of Service", "")
            } label: {
                Text("Terms of Service").font(.careBody)
            }
            .frame(minHeight: 44)
            NavigationLink {
                placeholderView("Privacy Policy", "")
            } label: {
                Text("Privacy Policy").font(.careBody)
            }
            .frame(minHeight: 44)
            NavigationLink {
                medicalDisclaimerView
            } label: {
                Text("Medical Disclaimer").font(.careBody)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Delete Account

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showDeleteConfirmation = true
            } label: {
                Label("Delete Account", systemImage: "trash.fill")
                    .font(.careBodyMedium)
                    .foregroundStyle(.careUrgent)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("Delete account. This action is permanent.")
            .confirmationDialog(
                "Delete your account?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete permanently", role: .destructive) {
                    Task { await viewModel.deleteAccount(container: container) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All your data, care history, and loved one records will be permanently deleted. This cannot be undone.")
            }
        } footer: {
            Text("Version 1.0.0 · Build 100")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
        }
    }

    // MARK: Medical Disclaimer View

    private var medicalDisclaimerView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Medical Disclaimer")
                    .font(.careDisplayMedium)
                Text("Cura is a care coordination platform. It is not a medical device and does not provide medical advice, diagnosis, or treatment recommendations.")
                    .font(.careBody).foregroundStyle(.textPrimary)
                Text("Care observations, alerts, and summaries generated by Cura are based solely on information entered by caregivers and family members. They are not reviewed by medical professionals and should not be used as a substitute for professional medical advice.")
                    .font(.careBody).foregroundStyle(.textPrimary)
                Text("Always consult a qualified healthcare provider for any health concerns regarding your loved one. In an emergency, call emergency services immediately.")
                    .font(.careBody).foregroundStyle(.textPrimary)
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Medical Disclaimer")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: Helpers

    private func settingsRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body.weight(.semibold))
                .frame(width: 28)
            Text(label)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
        }
    }

    private func placeholderView(_ title: String, _ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(title).font(.careDisplayMedium)
            if !message.isEmpty {
                Text(message).font(.careBody).foregroundStyle(.textSecondary).multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#Preview {
    FamilySettingsView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
