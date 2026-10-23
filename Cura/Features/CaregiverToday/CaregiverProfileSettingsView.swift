import SwiftUI
import Observation

@MainActor
@Observable
final class CaregiverProfileViewModel {
    var caregiver: Caregiver = SampleData.caregiver
    var isSaving: Bool = false
    var showDeleteConfirm: Bool = false

    var notificationsEnabled: Bool = true
    var familyMessageNotifications: Bool = true
    var scheduleReminders: Bool = true
    var translationEnabled: Bool = true
    var displayLanguage: LanguageCode = .marathi

    func save() async {
        isSaving = true
        try? await Task.sleep(nanoseconds: 600_000_000)
        isSaving = false
    }
}

struct CaregiverProfileSettingsView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = CaregiverProfileViewModel()
    @State private var editingBio = false

    var body: some View {
        NavigationStack {
            List {
                profileHeaderSection
                publicProfileSection
                availabilitySection
                documentsSection
                earningsSection
                notificationsSection
                languageSection
                privacySection
                safetySection
                dangerZoneSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PrimaryButton("Save", isLoading: viewModel.isSaving) {
                        Task { await viewModel.save() }
                    }
                    .frame(width: 90)
                }
            }
            .alert("Delete Account", isPresented: $viewModel.showDeleteConfirm) {
                Button("Delete Permanently", role: .destructive) {}
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all data. This cannot be undone.")
            }
        }
    }

    // MARK: - Sections

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: CuraSpacing.md) {
                Circle()
                    .fill(Color.curaBlue.opacity(0.15))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text(viewModel.caregiver.name.prefix(1))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.curaBlue)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Button(action: {}) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.curaBlue)
                                .clipShape(Circle())
                        }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.caregiver.name)
                        .font(.curaTitle)
                    Text("⭐️ \(String(format: "%.1f", viewModel.caregiver.rating))  ·  \(viewModel.caregiver.totalVisits) visits")
                        .font(.curaCaption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, CuraSpacing.sm)
        }
    }

    private var publicProfileSection: some View {
        Section("Public Profile") {
            LabeledContent("Name") {
                TextField("Your name", text: $viewModel.caregiver.name)
                    .multilineTextAlignment(.trailing)
            }
            .frame(minHeight: 44)

            LabeledContent("Preferred Name") {
                TextField("Preferred name", text: $viewModel.caregiver.preferredName)
                    .multilineTextAlignment(.trailing)
            }
            .frame(minHeight: 44)

            NavigationLink("Bio") {
                BioEditView(bio: $viewModel.caregiver.bio)
            }
            .frame(minHeight: 44)

            NavigationLink("Languages (\(viewModel.caregiver.languages.count))") {
                LanguagePickerView(selected: $viewModel.caregiver.languages)
            }
            .frame(minHeight: 44)

            NavigationLink("Specialties (\(viewModel.caregiver.specialties.count))") {
                Text("Specialties").navigationTitle("Specialties")
            }
            .frame(minHeight: 44)
        }
    }

    private var availabilitySection: some View {
        Section("Availability & Service Area") {
            NavigationLink("Availability") {
                Text("Availability editor").navigationTitle("Availability")
            }
            .frame(minHeight: 44)
            LabeledContent("Service Area") {
                Text(viewModel.caregiver.serviceArea)
                    .foregroundStyle(.secondary)
                    .font(.curaBody)
            }
            .frame(minHeight: 44)
        }
    }

    private var documentsSection: some View {
        Section("Documents & Verification") {
            ForEach(viewModel.caregiver.verificationBadges, id: \.self) { badge in
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.curaSuccess)
                    Text(badge).font(.curaBody)
                    Spacer()
                    StatusBadge("Verified", color: .curaSuccess)
                }
                .frame(minHeight: 44)
            }
            Button(action: {}) {
                Label("Upload New Document", systemImage: "plus.circle")
                    .font(.curaBody).foregroundStyle(.curaBlue)
            }
            .frame(minHeight: 44)
        }
    }

    private var earningsSection: some View {
        Section("Earnings") {
            NavigationLink(destination: EarningsView()) {
                Label("View Earnings", systemImage: "indianrupeesign.circle.fill")
                    .foregroundStyle(.curaTeal)
            }
            .frame(minHeight: 44)
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("All Notifications", isOn: $viewModel.notificationsEnabled)
                .frame(minHeight: 44)
            Toggle("Family Messages", isOn: $viewModel.familyMessageNotifications)
                .frame(minHeight: 44).disabled(!viewModel.notificationsEnabled)
            Toggle("Schedule Reminders", isOn: $viewModel.scheduleReminders)
                .frame(minHeight: 44).disabled(!viewModel.notificationsEnabled)
        }
        .tint(.curaBlue)
    }

    private var languageSection: some View {
        Section("Language & Translation") {
            Toggle("Auto-translate Messages", isOn: $viewModel.translationEnabled)
                .frame(minHeight: 44)
            Picker("Display Language", selection: $viewModel.displayLanguage) {
                ForEach(LanguageCode.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .frame(minHeight: 44)
        }
        .tint(.curaBlue)
    }

    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink("Privacy Settings") {
                Text("Privacy").navigationTitle("Privacy")
            }
            .frame(minHeight: 44)
            NavigationLink("Data & Permissions") {
                Text("Data").navigationTitle("Data & Permissions")
            }
            .frame(minHeight: 44)
        }
    }

    private var safetySection: some View {
        Section("Safety") {
            NavigationLink("Safety Resources") {
                Text("Safety resources").navigationTitle("Safety")
            }
            .frame(minHeight: 44)
            NavigationLink("Incident Reports") {
                Text("Incident history").navigationTitle("Incident Reports")
            }
            .frame(minHeight: 44)
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive, action: { viewModel.showDeleteConfirm = true }) {
                Label("Delete Account", systemImage: "trash.fill")
            }
            .frame(minHeight: 44)
        }
    }
}

// MARK: - Sub-views

private struct BioEditView: View {
    @Binding var bio: String
    var body: some View {
        TextEditor(text: $bio)
            .font(.curaBody)
            .padding(CuraSpacing.sm)
            .navigationTitle("Bio")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LanguagePickerView: View {
    @Binding var selected: [LanguageCode]
    var body: some View {
        List(LanguageCode.allCases, id: \.self) { lang in
            HStack {
                Text(lang.rawValue).font(.curaBody)
                Spacer()
                if selected.contains(lang) {
                    Image(systemName: "checkmark").foregroundStyle(.curaBlue)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                if selected.contains(lang) {
                    selected.removeAll { $0 == lang }
                } else {
                    selected.append(lang)
                }
            }
        }
        .navigationTitle("Languages")
    }
}

#Preview {
    CaregiverProfileSettingsView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
