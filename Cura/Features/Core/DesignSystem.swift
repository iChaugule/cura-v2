import SwiftUI

// MARK: - Color Tokens (cura* names used internally; care* aliases for compatibility)

extension Color {
    // Primary palette
    static let curaTeal       = Color(red: 0.15, green: 0.70, blue: 0.67)
    static let curaBlue       = Color(red: 0.20, green: 0.52, blue: 0.92)
    static let curaCard       = Color(UIColor.secondarySystemGroupedBackground)
    static let curaBackground = Color(UIColor.systemGroupedBackground)
    static let curaUrgent     = Color(red: 0.92, green: 0.22, blue: 0.22)
    static let curaWarning    = Color(red: 0.96, green: 0.56, blue: 0.10)
    static let curaSuccess    = Color(red: 0.22, green: 0.76, blue: 0.44)

    // care* aliases (used by family-facing views)
    static let careAccentBlue  = curaBlue
    static let careAccentTeal  = curaTeal
    static let careCalm        = curaTeal
    static let careAttention   = curaWarning
    static let careUrgent      = curaUrgent
    static let carePositive    = curaSuccess
    static let surfaceRaised   = Color(UIColor.systemBackground)
    static let surfaceCard     = curaCard
    static let surfaceDepressed = Color(UIColor.systemGroupedBackground)
    static let textPrimary     = Color.primary
    static let textSecondary   = Color.secondary
    static let textMuted       = Color(UIColor.tertiaryLabel)

    static func alertColor(_ tier: AlertTier) -> Color {
        switch tier {
        case .urgent:         return .careUrgent
        case .contactCare:    return .careAttention
        case .monitorClosely: return .careAttention
        case .informational:  return .careAccentBlue
        }
    }
}

// MARK: - Font Tokens

extension Font {
    static let curaTitle    = Font.system(size: 22, weight: .bold,     design: .rounded)
    static let curaHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let curaBody     = Font.system(size: 15, weight: .regular,  design: .rounded)
    static let curaCaption  = Font.system(size: 12, weight: .regular,  design: .rounded)
    static let curaLarge    = Font.system(size: 28, weight: .bold,     design: .rounded)
    static let curaMono     = Font.system(size: 15, weight: .medium,   design: .monospaced)

    // care* aliases
    static let careDisplayLarge  = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let careDisplayMedium = Font.system(.title,      design: .rounded, weight: .semibold)
    static let careHeading       = Font.system(.title2,     design: .rounded, weight: .semibold)
    static let careSubheading    = Font.system(.title3,     design: .rounded, weight: .medium)
    static let careBody          = Font.system(.body,       design: .default, weight: .regular)
    static let careBodyMedium    = Font.system(.body,       design: .default, weight: .medium)
    static let careLabel         = Font.system(.callout,    design: .default, weight: .medium)
    static let careCaption       = Font.system(.caption,    design: .default, weight: .regular)
    static let careCaptionBold   = Font.system(.caption,    design: .default, weight: .semibold)
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// Alias
enum CuraSpacing {
    static let xs:         CGFloat = 4
    static let sm:         CGFloat = 8
    static let md:         CGFloat = 16
    static let lg:         CGFloat = 24
    static let xl:         CGFloat = 32
    static let cardRadius: CGFloat = 16
    static let chipRadius: CGFloat = 10
}

// MARK: - Corner Radii

enum Radius {
    static let xs:   CGFloat = 6
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 28
    static let pill: CGFloat = 999
}

// MARK: - CareCard

struct CareCard<Content: View>: View {
    var padding: CGFloat = CuraSpacing.md
    let content: Content

    init(padding: CGFloat = CuraSpacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.curaCard)
            .clipShape(RoundedRectangle(cornerRadius: CuraSpacing.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - PrimaryButton

enum ButtonStyle_: Sendable { case primary, secondary, destructive }

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle_ = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var overrideColor: Color? = nil
    let action: () -> Void

    // Labeled convenience
    init(title: String, style: ButtonStyle_ = .primary, isLoading: Bool = false,
         isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    // Unlabeled first-arg convenience (agent-style: PrimaryButton("Save", icon:, isLoading:) { })
    init(_ title: String, icon: String? = nil, isLoading: Bool = false,
         isDisabled: Bool = false, color: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.overrideColor = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: Spacing.xs) {
                        if let icon {
                            Image(systemName: icon)
                        }
                        Text(title)
                    }
                    .font(.curaHeadline)
                    .foregroundStyle(foregroundColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel(title)
    }

    private var backgroundColor: Color {
        if let overrideColor { return overrideColor }
        switch style {
        case .primary:     return .curaBlue
        case .secondary:   return .curaCard
        case .destructive: return .curaUrgent
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .white
        case .secondary:   return .curaBlue
        case .destructive: return .white
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let label: String
    var icon: String? = nil
    var color: Color = .careAccentBlue

    // Full init: icon + label + alertTier (from DesignSystem alertColor)
    init(icon: String, label: String, tier: AlertTier) {
        self.icon = icon
        self.label = label
        self.color = .alertColor(tier)
    }

    // Compact init: label + explicit color (agent-style: StatusBadge("text", color: .curaWarning))
    init(_ label: String, color: Color = .careAccentBlue, icon: String? = nil) {
        self.label = label
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
            }
            Text(label)
                .font(.careCaption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) status")
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    private var trailingView: AnyView? = nil

    // Standard labeled init
    init(title: String, subtitle: String? = nil, action: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.onAction = onAction
    }

    // Unlabeled positional init (agent-style: SectionHeader("Title") or SectionHeader("Title", subtitle: "..."))
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    // ViewBuilder trailing (for custom action areas)
    init<T: View>(title: String, @ViewBuilder trailing: () -> T) {
        self.title = title
        self.trailingView = AnyView(trailing())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)
                Spacer()
                if let trailingView {
                    trailingView
                } else if let action, let onAction {
                    Button(action: onAction) {
                        Text(action)
                            .font(.careLabel)
                            .foregroundStyle(.careAccentBlue)
                    }
                    .accessibilityLabel("\(action) for \(title)")
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.careCaption)
                    .foregroundStyle(.textSecondary)
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.textSecondary)
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)
                Text(message)
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.horizontal, Spacing.xl)
            }
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.careBody)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chip / Tag

struct TagChip: View {
    let label: String
    var color: Color = .careAccentBlue
    var isSelected: Bool = false

    var body: some View {
        Text(label)
            .font(.careCaption)
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? color : color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Translation Label

struct TranslationLabel: View {
    let fromLanguage: String
    var onShowOriginal: (() -> Void)? = nil

    var body: some View {
        Button(action: { onShowOriginal?() }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.caption2)
                Text("Translated from \(fromLanguage)")
                    .font(.careCaption)
            }
            .foregroundStyle(.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Machine translated from \(fromLanguage). Tap to see original.")
    }
}

// MARK: - ChipButton (selectable chip used in multi-select grids)

struct ChipButton: View {
    let title: String
    var isSelected: Bool = false
    var selectedColor: Color = .curaBlue
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.careCaption)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : selectedColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? selectedColor : selectedColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 36)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - WrapLayout (flow layout for chip grids, iOS 16+)

struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (subview, frame) in zip(subviews, result.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                         proposal: ProposedViewSize(frame.size))
        }
    }

    private struct LayoutResult {
        var frames: [CGRect]
        var totalSize: CGSize
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        var frames: [CGRect] = []
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return LayoutResult(frames: frames, totalSize: CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Observation Category (used by AddObservationView and TimelineView)

enum ObservationCategory: String, CaseIterable, Codable, Sendable {
    case moodBehavior     = "Mood & Behavior"
    case orientation      = "Orientation"
    case communication    = "Communication"
    case dailyFunctioning = "Daily Functioning"
    case safety           = "Safety"
}

// MARK: - VisitStatus display helpers

extension VisitStatus {
    var displayText: String { label }

    var badgeColor: Color {
        switch self {
        case .checkedIn, .inProgress:   return .curaBlue
        case .arriving, .confirmed:     return .curaTeal
        case .scheduled:                return .textSecondary
        case .late, .replacementNeeded: return .curaWarning
        case .cancelled:                return .curaUrgent
        case .completed:                return .curaSuccess
        case .noVisit:                  return .textSecondary
        }
    }
}

// MARK: - ActionGridCard (2-column action grid tile used in ActiveVisit/CaregiverToday)

struct ActionGridCard: View {
    let icon: String
    let label: String
    var iconColor: Color = .curaBlue
    var badge: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundStyle(iconColor)
                        .frame(width: 52, height: 52)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                    Text(label)
                        .font(.careCaption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.sm)
                .background(Color.curaCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))

                if let badge {
                    Text(badge)
                        .font(.careCaptionBold)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.curaWarning)
                        .clipShape(Circle())
                        .offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - EmergencyButton (red SOS button for toolbar)

struct EmergencyButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sos.circle.fill")
                .font(.title2)
                .foregroundStyle(.curaUrgent)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Emergency — call for help")
    }
}

// MARK: - TaskStatus display helpers

extension TaskStatus {
    var badgeColor: Color {
        switch self {
        case .completed:       return .curaSuccess
        case .scheduled:       return .curaBlue
        case .notConfirmed:    return .curaWarning
        case .declined, .unableToComplete: return .curaUrgent
        case .needsFollowUp:   return .curaWarning
        }
    }
}
