import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class ConcernAlertsViewModel {
    var alerts: [ConcernAlert] = SampleData.activeAlerts
    var isLoading: Bool = false
    var error: String? = nil

    var urgentAlerts: [ConcernAlert]     { alerts.filter { $0.tier == .urgent && !$0.isAcknowledged } }
    var monitorAlerts: [ConcernAlert]    { alerts.filter { $0.tier == .monitorClosely && !$0.isAcknowledged } }
    var infoAlerts: [ConcernAlert]       { alerts.filter { $0.tier == .informational && !$0.isAcknowledged } }
    var acknowledgedAlerts: [ConcernAlert] { alerts.filter { $0.isAcknowledged } }

    func load(container: ServiceContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            alerts = try await container.insightsService.concernAlerts(for: SampleData.lovedOne.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func acknowledge(_ alert: ConcernAlert, container: ServiceContainer) async {
        do {
            try await container.insightsService.acknowledgeAlert(alertId: alert.id)
            if let idx = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[idx].isAcknowledged = true
            }
        } catch { }
    }
}

// MARK: - Main View

struct ConcernAlertsView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = ConcernAlertsViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "Loading alerts…")
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.alerts.allSatisfy(\.isAcknowledged) && viewModel.alerts.isEmpty {
                    emptyState
                } else {
                    alertsList
                }
            }
            .navigationTitle("Concern Alerts")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.load(container: container) }
            .navigationDestination(for: ConcernAlert.self) { alert in
                AlertDetailView(alert: alert)
            }
        }
    }

    // MARK: List

    private var alertsList: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if !viewModel.urgentAlerts.isEmpty {
                    alertSection(
                        tier: .urgent,
                        title: "Urgent",
                        icon: "exclamationmark.circle.fill",
                        color: .careUrgent,
                        alerts: viewModel.urgentAlerts
                    )
                }
                if !viewModel.monitorAlerts.isEmpty {
                    alertSection(
                        tier: .monitorClosely,
                        title: "Monitor Closely",
                        icon: "exclamationmark.triangle.fill",
                        color: .careAttention,
                        alerts: viewModel.monitorAlerts
                    )
                }
                if !viewModel.infoAlerts.isEmpty {
                    alertSection(
                        tier: .informational,
                        title: "Informational",
                        icon: "info.circle.fill",
                        color: .careAccentBlue,
                        alerts: viewModel.infoAlerts
                    )
                }
                if !viewModel.acknowledgedAlerts.isEmpty {
                    acknowledgedSection
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: Alert Section

    private func alertSection(tier: AlertTier, title: String, icon: String, color: Color, alerts: [ConcernAlert]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.careHeading)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("\(alerts.count)")
                    .font(.careCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(color)
                    .clipShape(Capsule())
            }
            ForEach(alerts) { alert in
                alertRow(alert, color: color)
            }
        }
    }

    private func alertRow(_ alert: ConcernAlert, color: Color) -> some View {
        CareCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: tierIcon(alert.tier))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(alert.headline)
                            .font(.careBodyMedium)
                            .foregroundStyle(.textPrimary)
                        Text(alert.createdAt, style: .relative)
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                    Spacer()
                    acknowledgeButton(alert)
                }

                if !alert.briefDetail.isEmpty {
                    Text(alert.briefDetail)
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: Spacing.sm) {
                    Button {
                        navigationPath.append(alert)
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption.weight(.semibold))
                            Text("Show me why")
                                .font(.careBodyMedium)
                        }
                        .foregroundStyle(color)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(color.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Show why this alert was triggered")

                    Spacer()
                }
            }
            .padding(Spacing.md)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(color)
                .frame(width: 4)
                .clipShape(
                    .rect(
                        topLeadingRadius: Radius.lg,
                        bottomLeadingRadius: Radius.lg,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )
        }
    }

    private func acknowledgeButton(_ alert: ConcernAlert) -> some View {
        Button {
            Task { await viewModel.acknowledge(alert, container: container) }
        } label: {
            Image(systemName: alert.isAcknowledged ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(alert.isAcknowledged ? .carePositive : .textSecondary)
                .font(.title3)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(alert.isAcknowledged ? "Acknowledged" : "Acknowledge this alert")
    }

    // MARK: Acknowledged Section

    private var acknowledgedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Acknowledged")
            ForEach(viewModel.acknowledgedAlerts) { alert in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.carePositive)
                    Text(alert.headline)
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(alert.createdAt, style: .relative)
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Acknowledged: \(alert.headline)")
            }
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "checkmark.shield.fill",
            title: "All clear",
            message: "No active concern alerts for \(SampleData.lovedOne.name) right now."
        )
    }

    // MARK: Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.careAttention)
            Text("Could not load alerts")
                .font(.careHeading)
            Text(message).font(.careBody).foregroundStyle(.textSecondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.load(container: container) } }
                .buttonStyle(PrimaryButtonStyle(style: .primary))
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    private func tierIcon(_ tier: AlertTier) -> String {
        switch tier {
        case .urgent:         return "exclamationmark.circle.fill"
        case .monitorClosely: return "exclamationmark.triangle.fill"
        case .informational:  return "info.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ConcernAlertsView()
        .environment(ServiceContainer.preview)
        .environment(AppSession.preview)
}
