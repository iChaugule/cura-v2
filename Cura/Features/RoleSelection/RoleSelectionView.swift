import SwiftUI

// MARK: - RoleSelectionView

struct RoleSelectionView: View {
    var initialIntent: AuthIntent = .signUp

    @State private var navigateTo: RoleSelectionDestination?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    headerSection
                    cardsSection
                    signInLink
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $navigateTo) { destination in
                switch destination {
                case .authAsFamily:
                    AuthView(role: .familyMember, intent: initialIntent)
                case .authAsCaregiver:
                    AuthView(role: .caregiver, intent: initialIntent)
                case .signIn:
                    AuthView(role: .familyMember, intent: .signIn)
                }
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.careAccentBlue)

            Text("How are you using Cura?")
                .font(.careDisplayLarge)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)

            Text("Choose your role — you can have both.")
                .font(.careBody)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: Role Cards

    private var cardsSection: some View {
        VStack(spacing: Spacing.md) {
            roleCard(
                icon: "house.heart.fill",
                title: "I'm supporting a family member",
                subtitle: "Find and hire caregivers, follow daily care, and stay connected in your own language.",
                buttonTitle: "Get Started as Family Member",
                gradientColors: [Color.careAccentTeal, Color.careAccentTeal.opacity(0.6)],
                action: { navigateTo = .authAsFamily }
            )

            roleCard(
                icon: "hands.and.sparkles.fill",
                title: "I provide care",
                subtitle: "Receive assignments, log daily care, and stay in touch with the families you support.",
                buttonTitle: "Get Started as Caregiver",
                gradientColors: [Color.careAccentBlue, Color.careAccentBlue.opacity(0.6)],
                action: { navigateTo = .authAsCaregiver }
            )
        }
    }

    private func roleCard(
        icon: String,
        title: String,
        subtitle: String,
        buttonTitle: String,
        gradientColors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Icon + gradient header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 90)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: Radius.xl,
                    topTrailingRadius: Radius.xl
                ))

                Image(systemName: icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.leading, Spacing.lg)
                    .padding(.bottom, Spacing.md)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }

            // Text + button
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title)
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)

                Text(subtitle)
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                Button(action: action) {
                    Text(buttonTitle)
                        .font(.careBodyMedium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(gradientColors.first ?? .careAccentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
                }
                .padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: Sign In Link

    private var signInLink: some View {
        Button {
            navigateTo = .signIn
        } label: {
            Text("Sign in to an existing account")
                .font(.careBodyMedium)
                .foregroundStyle(.careAccentBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
        }
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Navigation Destination

private enum RoleSelectionDestination: Hashable, Identifiable {
    case authAsFamily
    case authAsCaregiver
    case signIn

    var id: Self { self }
}

// MARK: - Preview

#Preview {
    RoleSelectionView()
        .environment(AppSession.onboardedSignedOut)
        .environment(ServiceContainer.preview)
}
