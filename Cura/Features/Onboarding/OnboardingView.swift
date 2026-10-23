import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage: Identifiable {
    let id: Int
    let illustration: OnboardingIllustration
    let heading: String
    let body: String
    let isDisclaimer: Bool

    init(id: Int, illustration: OnboardingIllustration, heading: String, body: String, isDisclaimer: Bool = false) {
        self.id = id
        self.illustration = illustration
        self.heading = heading
        self.body = body
        self.isDisclaimer = isDisclaimer
    }
}

private enum OnboardingIllustration {
    case heartCircle
    case memoryPassport
    case speechBubble
    case trendChart
    case disclaimer
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppSession.self) private var session
    @State private var currentPage = 0
    @State private var navigateToRoleSelection = false
    @State private var authIntent: AuthIntent = .signUp

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            illustration: .heartCircle,
            heading: "Support your loved one from anywhere",
            body: "Stay connected with daily care updates, real-time messages from caregivers, and the peace of mind that comes from knowing someone you trust is there."
        ),
        OnboardingPage(
            id: 1,
            illustration: .memoryPassport,
            heading: "Care built around the person",
            body: "A Memory Care Passport captures routines, preferences, history, and what matters most — so every caregiver shows up already knowing your loved one."
        ),
        OnboardingPage(
            id: 2,
            illustration: .speechBubble,
            heading: "Speak your language, not theirs",
            body: "Communicate naturally in your preferred language. Cura bridges the gap between families and caregivers across any language barrier, automatically and privately."
        ),
        OnboardingPage(
            id: 3,
            illustration: .trendChart,
            heading: "Notice changes sooner",
            body: "Cura tracks patterns in sleep, appetite, mood, and mobility over time — surfacing subtle shifts early so you can act before small changes become big concerns."
        ),
        OnboardingPage(
            id: 4,
            illustration: .disclaimer,
            heading: "Not a replacement for emergency care",
            body: "For urgent medical concerns, contact local emergency services or a qualified healthcare professional. Cura is a coordination and support tool, not a medical device or emergency service.",
            isDisclaimer: true
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        pageView(page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .top)

                // Bottom overlay: dots + buttons
                bottomOverlay
            }
            .navigationDestination(isPresented: $navigateToRoleSelection) {
                RoleSelectionView(initialIntent: authIntent)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            session.onboardingComplete = true
                            navigateToRoleSelection = true
                        }
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                illustrationView(page.illustration, isDisclaimer: page.isDisclaimer)
                    .padding(.top, 80)

                VStack(spacing: Spacing.md) {
                    if page.isDisclaimer {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.careAttention)
                            Text("Important notice")
                                .font(.careBodyMedium)
                                .foregroundStyle(Color.careAttention)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.careAttention.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    }

                    Text(page.heading)
                        .font(.careDisplayMedium)
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.body)
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 180) // Space for bottom overlay
            }
        }
    }

    // MARK: - Illustrations

    @ViewBuilder
    private func illustrationView(_ type: OnboardingIllustration, isDisclaimer: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.xxl)
                .fill(illustrationBackground(type))
                .frame(width: 220, height: 220)

            illustrationContent(type)
        }
    }

    private func illustrationBackground(_ type: OnboardingIllustration) -> Color {
        switch type {
        case .heartCircle:    return Color.careAccentTeal.opacity(0.15)
        case .memoryPassport: return Color.careAccentBlue.opacity(0.12)
        case .speechBubble:   return Color.careCalm.opacity(0.15)
        case .trendChart:     return Color.careAccentTeal.opacity(0.12)
        case .disclaimer:     return Color.careAttention.opacity(0.10)
        }
    }

    @ViewBuilder
    private func illustrationContent(_ type: OnboardingIllustration) -> some View {
        switch type {
        case .heartCircle:
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.careAccentTeal)
        case .memoryPassport:
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.careAccentBlue)
        case .speechBubble:
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.careCalm)
        case .trendChart:
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 72))
                .foregroundStyle(Color.careAccentTeal)
        case .disclaimer:
            Image(systemName: "cross.case.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.careAttention)
        }
    }

    // MARK: - Bottom Overlay

    private var bottomOverlay: some View {
        VStack(spacing: Spacing.md) {
            // Page dots
            HStack(spacing: Spacing.xs) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.careAccentBlue : Color.careAccentBlue.opacity(0.25))
                        .frame(width: index == currentPage ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding(.bottom, Spacing.xs)

            // Buttons
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Get Started") {
                    authIntent = .signUp
                    session.onboardingComplete = true
                    navigateToRoleSelection = true
                }

                Button {
                    authIntent = .signIn
                    session.onboardingComplete = true
                    navigateToRoleSelection = true
                } label: {
                    Text("Sign In")
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.careAccentBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(.systemBackground).opacity(0), location: 0),
                    .init(color: Color(.systemBackground).opacity(1), location: 0.25),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Auth Intent

enum AuthIntent {
    case signIn
    case signUp
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AppSession.notOnboarded)
        .environment(ServiceContainer.preview)
}
