import SwiftUI

// MARK: - EmergencyView

struct EmergencyView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var showPassportSheet = false
    @State private var showIncidentReport = false

    private var lovedOne: LovedOne { SampleData.lovedOne }
    private var caregiver: Caregiver? { SampleData.caregivers.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    disclaimerBanner
                    Spacer(minLength: Spacing.xs)
                    actionCards
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Emergency Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showPassportSheet) {
                passportEmergencySheet
            }
            .sheet(isPresented: $showIncidentReport) {
                IncidentReportView()
            }
        }
    }

    // MARK: Disclaimer Banner

    private var disclaimerBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.careAttention)
                .font(.body)
                .frame(width: 28, height: 28)
            Text("Cura is not an emergency-response service. Use the options below to reach emergency services or people who can help.")
                .font(.careCaption)
                .foregroundStyle(Color.careAttention)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(Spacing.md)
        .background(Color.careAttention.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    // MARK: Action Cards

    private var actionCards: some View {
        VStack(spacing: Spacing.sm) {
            callEmergencyServicesButton
            callPrimaryFamilyButton
            callCaregiverButton
            viewEmergencyInfoButton
            contactCuraSupportButton
            reportIncidentButton
        }
    }

    // MARK: 1 — Emergency Services

    private var callEmergencyServicesButton: some View {
        emergencyActionCard(
            priority: .primary,
            icon: "phone.fill",
            iconColor: .white,
            backgroundColor: Color.careUrgent,
            title: "Call Local Emergency Services",
            subtitle: emergencyNumber,
            accessibilityHint: "Calls \(emergencyNumber) immediately"
        ) {
            if let url = URL(string: "tel://\(emergencyPhoneNumber)") {
                UIApplication.shared.open(url)
            }
        }
    }

    private var emergencyNumber: String {
        countryEmergencyNumber(for: lovedOne.countryCode ?? "IN")
    }

    private var emergencyPhoneNumber: String {
        countryEmergencyPhoneNumber(for: lovedOne.countryCode ?? "IN")
    }

    private func countryEmergencyNumber(for code: String) -> String {
        switch code {
        case "IN": return "112 (India National Emergency)"
        case "US": return "911 (US Emergency)"
        case "GB": return "999 (UK Emergency)"
        case "AU": return "000 (Australia Emergency)"
        default:   return "112 (International Emergency)"
        }
    }

    private func countryEmergencyPhoneNumber(for code: String) -> String {
        switch code {
        case "IN": return "112"
        case "US": return "911"
        case "GB": return "999"
        case "AU": return "000"
        default:   return "112"
        }
    }

    // MARK: 2 — Primary Family Contact

    private var callPrimaryFamilyButton: some View {
        emergencyActionCard(
            priority: .secondary,
            icon: "person.fill",
            iconColor: .careAccentBlue,
            backgroundColor: Color.surfaceCard,
            title: "Call Primary Family Contact",
            subtitle: lovedOne.emergencyContactName ?? "No contact listed",
            accessibilityHint: "Calls the primary family contact"
        ) {
            if let phone = lovedOne.emergencyContactPhone,
               let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: 3 — Caregiver

    private var callCaregiverButton: some View {
        emergencyActionCard(
            priority: .secondary,
            icon: "hands.and.sparkles.fill",
            iconColor: .careAccentBlue,
            backgroundColor: Color.surfaceCard,
            title: "Contact Current Caregiver",
            subtitle: caregiver?.name ?? "No caregiver on shift",
            accessibilityHint: "Calls or messages the current caregiver"
        ) {
            if let phone = caregiver?.phone,
               let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: 4 — Emergency Info Sheet

    private var viewEmergencyInfoButton: some View {
        emergencyActionCard(
            priority: .secondary,
            icon: "doc.text.fill",
            iconColor: .careAccentTeal,
            backgroundColor: Color.surfaceCard,
            title: "View Emergency Information",
            subtitle: "Passport emergency section",
            accessibilityHint: "Opens the care passport emergency section"
        ) {
            showPassportSheet = true
        }
    }

    // MARK: 5 — Cura Support

    private var contactCuraSupportButton: some View {
        emergencyActionCard(
            priority: .tertiary,
            icon: "headphones",
            iconColor: .textSecondary,
            backgroundColor: Color.surfaceCard,
            title: "Contact Cura Support",
            subtitle: "Available 24/7",
            accessibilityHint: "Opens Cura support contact options"
        ) {
            if let url = URL(string: "https://cura.app/support") {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: 6 — Report Incident

    private var reportIncidentButton: some View {
        Button {
            showIncidentReport = true
        } label: {
            Text("Report an Incident")
                .font(.careBodyMedium)
                .foregroundStyle(.careAccentBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
        }
        .accessibilityLabel("Report an incident")
    }

    // MARK: Card Builder

    private enum ActionPriority { case primary, secondary, tertiary }

    private func emergencyActionCard(
        priority: ActionPriority,
        icon: String,
        iconColor: Color,
        backgroundColor: Color,
        title: String,
        subtitle: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(priority == .primary ? Color.white.opacity(0.25) : iconColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(priority == .primary ? Color.white : iconColor)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.careBodyMedium)
                        .foregroundStyle(priority == .primary ? Color.white : Color.textPrimary)
                    Text(subtitle)
                        .font(.careCaption)
                        .foregroundStyle(priority == .primary ? Color.white.opacity(0.85) : Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(priority == .primary ? Color.white.opacity(0.8) : Color.textSecondary)
            }
            .padding(Spacing.md)
            .frame(minHeight: 72)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
            .shadow(
                color: priority == .primary ? Color.careUrgent.opacity(0.3) : Color.black.opacity(0.04),
                radius: priority == .primary ? 8 : 4,
                x: 0,
                y: priority == .primary ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: Passport Emergency Sheet

    private var passportEmergencySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    sectionCard(title: "Medical conditions") {
                        Text(lovedOne.medicalConditionsSummary ?? "Moderate dementia, hypertension, type 2 diabetes.")
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                            .lineSpacing(3)
                    }

                    sectionCard(title: "Medications") {
                        Text("Donepezil 10mg (evening), Metformin 500mg (morning/evening), Amlodipine 5mg (morning).")
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                            .lineSpacing(3)
                    }

                    sectionCard(title: "Allergies") {
                        Text(lovedOne.allergies ?? "Penicillin (severe). No known food allergies.")
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                            .lineSpacing(3)
                    }

                    sectionCard(title: "Emergency contacts") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            contactRow(name: lovedOne.emergencyContactName ?? "Raj Chaugule", relation: "Son", phone: "+91 98765 43210")
                            contactRow(name: "Dr. Meera Joshi", relation: "Family Physician", phone: "+91 22 2345 6789")
                        }
                    }

                    sectionCard(title: "Hospital preference") {
                        Text("Kokilaben Dhirubhai Ambani Hospital, Mumbai. Dr. Meera Joshi (Geriatrics).")
                            .font(.careBody)
                            .foregroundStyle(.textPrimary)
                            .lineSpacing(3)
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Emergency Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showPassportSheet = false }
                }
            }
        }
    }

    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.careBodyMedium)
                .foregroundStyle(.textPrimary)
            CareCard {
                content()
                    .padding(Spacing.md)
            }
        }
    }

    private func contactRow(name: String, relation: String, phone: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(.careAccentBlue)
                .font(.body)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(name).font(.careBodyMedium).foregroundStyle(.textPrimary)
                Text(relation).font(.careCaption).foregroundStyle(.textSecondary)
            }
            Spacer()
            Text(phone)
                .font(.careCaption)
                .foregroundStyle(.careAccentBlue)
        }
    }
}

// MARK: - Preview

#Preview {
    EmergencyView()
        .environment(AppSession.preview)
        .environment(ServiceContainer.preview)
}
