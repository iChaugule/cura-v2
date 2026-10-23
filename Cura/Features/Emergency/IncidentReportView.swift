import SwiftUI

// MARK: - Incident Category

enum IncidentCategory: String, CaseIterable, Identifiable {
    case fall             = "Fall"
    case injury           = "Injury"
    case missingPerson    = "Missing Person"
    case medicationError  = "Medication Error"
    case propertyIssue    = "Property Issue"
    case conflict         = "Conflict"
    case other            = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fall:            return "figure.fall"
        case .injury:          return "bandage.fill"
        case .missingPerson:   return "person.fill.questionmark"
        case .medicationError: return "pill.fill"
        case .propertyIssue:   return "house.fill"
        case .conflict:        return "person.2.slash.fill"
        case .other:           return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Notified Person

private struct NotifiedPerson: Identifiable {
    let id = UUID()
    let name: String
    var isNotified: Bool = false
    var notifiedAt: Date = Date()
}

// MARK: - IncidentReportViewModel

@MainActor
@Observable
final class IncidentReportViewModel {
    var selectedCategory: IncidentCategory = .fall
    var whatHappened: String = ""
    var whenDate: Date = Date()
    var actionTaken: String = ""
    var followUpRequired: Bool = false
    var showSubmitConfirmation: Bool = false
    var isSubmitting: Bool = false
    var isSubmitted: Bool = false

    var presentPeople: [NotifiedPerson] = [
        NotifiedPerson(name: "Priya Kadam (Caregiver)"),
        NotifiedPerson(name: "Kamala Chaugule (Loved One)"),
        NotifiedPerson(name: "Raj Chaugule (Family)"),
    ]

    var notifiedPeople: [NotifiedPerson] = [
        NotifiedPerson(name: "Raj Chaugule"),
        NotifiedPerson(name: "Dr. Meera Joshi"),
        NotifiedPerson(name: "Cura Support"),
    ]

    var canSubmit: Bool {
        !whatHappened.trimmingCharacters(in: .whitespaces).isEmpty &&
        !actionTaken.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        // Simulate network call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isSubmitted = true
    }
}

// MARK: - IncidentReportView

struct IncidentReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = IncidentReportViewModel()

    var body: some View {
        NavigationStack {
            if viewModel.isSubmitted {
                submittedView
            } else {
                formView
            }
        }
    }

    // MARK: Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                immutabilityNotice

                categorySection
                whatHappenedSection
                whenSection
                whoWasPresentSection
                actionTakenSection
                whoWasNotifiedSection
                followUpSection

                submitButton
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Report an Incident")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .confirmationDialog(
            "Submit this report?",
            isPresented: $viewModel.showSubmitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Submit Report", role: .destructive) {
                Task { await viewModel.submit() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Once submitted, this report cannot be edited. Corrections must be appended as a separate note.")
        }
    }

    // MARK: Immutability Notice

    private var immutabilityNotice: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.textSecondary)
                .font(.caption)
            Text("Incident reports are immutable once submitted. Corrections must be appended.")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.sm)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding(.top, Spacing.sm)
    }

    // MARK: Category

    private var categorySection: some View {
        formSection(title: "Incident category") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(IncidentCategory.allCases) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
            }
            .padding(.horizontal, -Spacing.md)
        }
    }

    private func categoryChip(_ category: IncidentCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            viewModel.selectedCategory = category
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.semibold))
                Text(category.rawValue)
                    .font(.careCaption)
            }
            .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(isSelected ? Color.careAccentBlue : Color.surfaceCard)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: What happened

    private var whatHappenedSection: some View {
        formSection(title: "What happened") {
            TextEditor(text: $viewModel.whatHappened)
                .font(.careBody)
                .frame(minHeight: 100)
                .padding(Spacing.sm)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }

    // MARK: When

    private var whenSection: some View {
        formSection(title: "When did it happen") {
            DatePicker("Date and time", selection: $viewModel.whenDate)
                .datePickerStyle(.compact)
                .tint(.careAccentBlue)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Who was present

    private var whoWasPresentSection: some View {
        formSection(title: "Who was present") {
            VStack(spacing: Spacing.xs) {
                ForEach($viewModel.presentPeople) { $person in
                    toggleRow(name: person.name, isOn: $person.isNotified)
                }
            }
        }
    }

    // MARK: Action taken

    private var actionTakenSection: some View {
        formSection(title: "Action taken") {
            TextEditor(text: $viewModel.actionTaken)
                .font(.careBody)
                .frame(minHeight: 100)
                .padding(Spacing.sm)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }

    // MARK: Who was notified

    private var whoWasNotifiedSection: some View {
        formSection(title: "Who was notified") {
            VStack(spacing: Spacing.xs) {
                ForEach($viewModel.notifiedPeople) { $person in
                    VStack(spacing: Spacing.xs) {
                        toggleRow(name: person.name, isOn: $person.isNotified)
                        if person.isNotified {
                            DatePicker(
                                "Notified at",
                                selection: $person.notifiedAt,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .tint(.careAccentBlue)
                            .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    // MARK: Follow Up

    private var followUpSection: some View {
        formSection(title: "Follow-up") {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Follow-up required")
                        .font(.careBodyMedium)
                        .foregroundStyle(.textPrimary)
                    Text("Mark this for review by the care coordinator")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $viewModel.followUpRequired)
                    .tint(.careAccentBlue)
            }
        }
    }

    // MARK: Submit

    private var submitButton: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(
                title: "Submit Report",
                isLoading: viewModel.isSubmitting,
                isDisabled: !viewModel.canSubmit
            ) {
                viewModel.showSubmitConfirmation = true
            }

            if !viewModel.canSubmit {
                Text("Complete all required fields before submitting.")
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Submitted View

    private var submittedView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.carePositive.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.carePositive)
            }
            VStack(spacing: Spacing.sm) {
                Text("Report Submitted")
                    .font(.careDisplayMedium)
                    .foregroundStyle(.textPrimary)
                Text("The incident has been logged. The care coordinator has been notified. You can append corrections as a new note if needed.")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, Spacing.xl)
            Spacer()
            PrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal, Spacing.md)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Incident Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Helpers

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.careBodyMedium)
                .foregroundStyle(.textPrimary)
            CareCard {
                VStack(spacing: 0) {
                    content()
                        .padding(Spacing.md)
                }
            }
        }
    }

    private func toggleRow(name: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(name)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(.careAccentBlue)
                .labelsHidden()
        }
    }
}

// MARK: - Preview

#Preview {
    IncidentReportView()
        .environment(AppSession.preview)
        .environment(ServiceContainer.preview)
}
