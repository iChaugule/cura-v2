import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class CaregiverProfileViewModel {
    var caregiver: Caregiver
    var isSaved: Bool = false
    var showBookingSheet: Bool = false
    var isLoading: Bool = false

    init(caregiver: Caregiver) {
        self.caregiver = caregiver
    }

    func toggleSave(container: ServiceContainer) async {
        isSaved.toggle()
        do {
            if isSaved {
                try await container.caregiverService.saveCaregiver(caregiver)
            } else {
                try await container.caregiverService.unsaveCaregiver(caregiver)
            }
        } catch {
            isSaved.toggle() // revert
        }
    }
}

// MARK: - Main View

struct CaregiverProfileView: View {
    let caregiver: Caregiver
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel: CaregiverProfileViewModel
    @State private var showMatchExplanation: Bool = false

    init(caregiver: Caregiver) {
        self.caregiver = caregiver
        self._viewModel = State(initialValue: CaregiverProfileViewModel(caregiver: caregiver))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                VStack(spacing: Spacing.lg) {
                    aboutSection
                    verificationBadges
                    experienceSection
                    statsSection
                    matchExplanationSection
                    reviewsSection
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, 120) // room for sticky bar
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(caregiver.firstName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.toggleSave(container: container) }
                } label: {
                    Image(systemName: viewModel.isSaved ? "heart.fill" : "heart")
                        .foregroundStyle(viewModel.isSaved ? .careUrgent : .textSecondary)
                }
                .accessibilityLabel(viewModel.isSaved ? "Remove from saved caregivers" : "Save caregiver")
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .overlay(alignment: .bottom) { stickyBottomBar }
        .sheet(isPresented: $viewModel.showBookingSheet) { bookingPlaceholderSheet }
    }

    // MARK: Header

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.careAccentBlue.opacity(0.3), Color.careAccentTeal.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)

            VStack(spacing: Spacing.sm) {
                caregiverPhoto
                Text(caregiver.firstName)
                    .font(.careDisplayMedium)
                    .foregroundStyle(.textPrimary)
                HStack(spacing: Spacing.sm) {
                    Label(caregiver.city, systemImage: "mappin.circle.fill")
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                    Text("·")
                        .foregroundStyle(.textSecondary)
                    Text("\(caregiver.yearsExperience) years exp.")
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                }
                rateRow
            }
            .padding(.bottom, Spacing.lg)
        }
    }

    private var caregiverPhoto: some View {
        ZStack {
            Circle()
                .fill(Color.careAccentTeal.opacity(0.2))
            if let url = caregiver.photoUrl {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    photoInitials
                }
                .clipShape(Circle())
            } else {
                photoInitials
            }
        }
        .frame(width: 100, height: 100)
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 4)
        )
        .shadow(radius: 4)
    }

    private var photoInitials: some View {
        Text(String(caregiver.firstName.prefix(1)))
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(.careAccentTeal)
    }

    private var rateRow: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "star.fill")
                .foregroundStyle(.careAttention)
                .font(.body)
            Text(String(format: "%.1f", caregiver.rating))
                .font(.careBodyMedium)
                .foregroundStyle(.textPrimary)
            Text("(\(caregiver.reviewCount) reviews)")
                .font(.careBody)
                .foregroundStyle(.textSecondary)
            Text("·")
                .foregroundStyle(.textSecondary)
            Text("$\(Int(caregiver.hourlyRate))/hr")
                .font(.careBodyMedium)
                .foregroundStyle(.careAccentBlue)
        }
    }

    // MARK: Verification Badges

    private var verificationBadges: some View {
        HStack(spacing: Spacing.sm) {
            verificationBadge(icon: "checkmark.shield.fill", label: "Background check", verified: caregiver.isBackgroundChecked)
            verificationBadge(icon: "person.badge.key.fill", label: "Identity verified", verified: caregiver.isIdentityVerified)
            verificationBadge(icon: "star.bubble.fill", label: "References", verified: caregiver.isReferencesVerified)
        }
    }

    private func verificationBadge(icon: String, label: String, verified: Bool) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(verified ? .carePositive : .textSecondary)
            Text(label)
                .font(.careCaption)
                .foregroundStyle(verified ? .textPrimary : .textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(verified ? Color.carePositive.opacity(0.08) : Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(verified ? "Verified" : "Not verified")")
    }

    // MARK: About Section

    private var aboutSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionLabel("About")
                Text(caregiver.bio)
                    .font(.careBody)
                    .foregroundStyle(.textPrimary)
                languageRow
            }
            .padding(Spacing.md)
        }
    }

    private var languageRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Languages")
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .textCase(.uppercase)
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
        }
    }

    // MARK: Experience Section

    private var experienceSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionLabel("Experience & Training")
                HStack(spacing: Spacing.md) {
                    statItem(value: "\(caregiver.yearsExperience)", unit: "years", label: "Experience")
                    Divider().frame(height: 48)
                    statItem(value: caregiver.dementiaTrainingLevel, unit: "", label: "Dementia training")
                }
                if !caregiver.specialties.isEmpty {
                    Divider()
                    Text("Specialties")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                        .textCase(.uppercase)
                    FlowLayout(spacing: Spacing.xs) {
                        ForEach(caregiver.specialties, id: \.self) { specialty in
                            specialtyChip(specialty)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private func specialtyChip(_ text: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.careCaption)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .foregroundStyle(.carePositive)
        .background(Color.carePositive.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: Stats Section

    private var statsSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                sectionLabel("Track Record")
                HStack(spacing: 0) {
                    statItem(value: "\(Int(caregiver.onTimeRate * 100))%", unit: "", label: "On-time arrival")
                    Divider().frame(height: 48)
                    statItem(value: "\(Int(caregiver.cancellationRate * 100))%", unit: "", label: "Cancellation rate")
                    Divider().frame(height: 48)
                    statItem(value: "\(caregiver.completedVisits)", unit: "", label: "Completed visits")
                    Divider().frame(height: 48)
                    statItem(value: "\(caregiver.repeatFamiliesCount)", unit: "", label: "Repeat families")
                }
            }
            .padding(Spacing.md)
        }
    }

    private func statItem(value: String, unit: String, label: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.careDisplayMedium)
                    .foregroundStyle(.careAccentBlue)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
            }
            Text(label)
                .font(.careCaption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(unit)")
    }

    // MARK: Match Explanation

    private var matchExplanationSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.careAccentTeal)
                        .font(.body.weight(.semibold))
                    sectionLabel("Why a good match")
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    matchReasonRow(icon: "brain.head.profile", text: "Experienced with dementia and memory care")
                    matchReasonRow(icon: "bubble.left.and.bubble.right.fill", text: "Speaks Marathi — Aaji's primary language")
                    matchReasonRow(icon: "clock.fill", text: "Available on your requested schedule")
                    matchReasonRow(icon: "star.fill", text: "Highly rated by families with similar needs")
                }
            }
            .padding(Spacing.md)
        }
        .accessibilityElement(children: .combine)
    }

    private func matchReasonRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.careAccentTeal)
                .frame(width: 20)
            Text(text)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
        }
    }

    // MARK: Reviews

    private var reviewsSection: some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionLabel("Family Reviews")
                ForEach(sampleReviews) { review in
                    reviewRow(review)
                    if review.id != sampleReviews.last?.id { Divider() }
                }
            }
            .padding(Spacing.md)
        }
    }

    private var sampleReviews: [CareReview] {
        [
            CareReview(id: "1", reviewer: "Sunita M.", rating: 5, date: "July 2025", text: "Priya is incredibly gentle and patient. She communicates beautifully in Marathi with my mother-in-law and handles sundowning episodes with calm and care."),
            CareReview(id: "2", reviewer: "Ramesh K.", rating: 5, date: "June 2025", text: "We have had three caregivers for our father and Priya is by far the best. She arrives on time, documents everything, and truly notices the little changes."),
            CareReview(id: "3", reviewer: "Meena J.", rating: 4, date: "May 2025", text: "Very professional and warm. Would highly recommend for families managing dementia care."),
        ]
    }

    private func reviewRow(_ review: CareReview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(review.reviewer)
                    .font(.careBodyMedium)
                    .foregroundStyle(.textPrimary)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<review.rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.careAttention)
                    }
                }
                Text(review.date)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
            Text(review.text)
                .font(.careBody)
                .foregroundStyle(.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Review by \(review.reviewer), \(review.rating) stars, \(review.date). \(review.text)")
    }

    // MARK: Sticky Bottom Bar

    private var stickyBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: Spacing.sm) {
                Button {
                    Task { await viewModel.toggleSave(container: container) }
                } label: {
                    Image(systemName: viewModel.isSaved ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundStyle(viewModel.isSaved ? .careUrgent : .careAccentBlue)
                        .frame(width: 44, height: 44)
                        .background(Color.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .accessibilityLabel(viewModel.isSaved ? "Remove from saved" : "Save caregiver")

                Button {
                    viewModel.showBookingSheet = true
                } label: {
                    Text("Request Booking")
                        .font(.careBodyMedium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .background(Color.careAccentBlue)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityLabel("Request booking with \(caregiver.firstName)")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color(.systemBackground))
        }
    }

    // MARK: Booking Sheet

    private var bookingPlaceholderSheet: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.largeTitle)
                .foregroundStyle(.careAccentBlue)
            Text("Booking Request")
                .font(.careDisplayMedium)
            Text("Full booking flow coming soon.")
                .font(.careBody)
                .foregroundStyle(.textSecondary)
        }
        .padding(Spacing.xl)
        .presentationDetents([.medium])
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.careHeading)
            .foregroundStyle(.textPrimary)
    }
}

// MARK: - Supporting types

private struct CareReview: Identifiable {
    let id: String
    let reviewer: String
    let rating: Int
    let date: String
    let text: String
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for view in row.views {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var views: [LayoutSubview] = []
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? 300
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !rows[rows.count - 1].views.isEmpty {
                rows.append(Row())
                x = 0
            }
            rows[rows.count - 1].views.append(view)
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
        }
        return rows
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaregiverProfileView(caregiver: SampleData.caregivers[0])
    }
    .environment(ServiceContainer.preview)
    .environment(AppSession.preview)
}
