import Foundation
import Observation

// MARK: - BaselineManager
@Observable
@MainActor
final class BaselineManager {

    // MARK: - Storage
    private var anchorBaselines: [String: Baseline] = [:]
    private var adaptiveBaselines: [String: Baseline] = [:]
    private var rollingWindows: [String: [(date: Date, value: Double)]] = [:]

    private let windowSize = 14

    // Minimum MAD per metric prevents division-by-zero and over-sensitivity
    // on metrics that are naturally low-variance
    private let minimumMAD: [String: Double] = [
        "hydration":      50.0,
        "sleep_hours":     0.5,
        "mobility_score":  0.3,
        "mood_score":      0.3,
        "temperature":     0.2,
        "heart_rate":      3.0,
        "weight_kg":       0.5
    ]

    // MARK: - Init
    init(baselines: [Baseline] = []) {
        for baseline in baselines {
            let key = Self.key(personId: baseline.personId, metric: baseline.metric)
            if baseline.anchorValue != nil {
                anchorBaselines[key] = baseline
            }
            if baseline.adaptiveValue != nil {
                adaptiveBaselines[key] = baseline
            }
        }
    }

    // MARK: - Update
    /// Incorporate a new observation into the adaptive rolling baseline.
    func update(observation: Observation) {
        guard let value = observation.numericValue else { return }
        let k = Self.key(personId: observation.personId, metric: observation.metric)
        var window = rollingWindows[k, default: []]
        window.append((date: observation.timestamp, value: value))
        window.sort { $0.date < $1.date }
        if window.count > windowSize {
            window = Array(window.suffix(windowSize))
        }
        rollingWindows[k] = window

        guard window.count >= 3 else { return }
        let values = window.map { $0.value }
        let medianVal = median(values)
        let state: BaselineState = window.count >= 7 ? .established : .provisional
        let existing = adaptiveBaselines[k]
        adaptiveBaselines[k] = Baseline(
            id: existing?.id ?? UUID(),
            personId: observation.personId,
            metric: observation.metric,
            anchorValue: anchorBaselines[k]?.anchorValue,
            adaptiveValue: medianVal,
            state: state,
            lastUpdated: Date()
        )
    }

    // MARK: - Deviation from Anchor (robust z-score)
    /// Returns a robust z-score: (value − anchorMedian) / (1.4826 × MAD).
    /// Returns 0 if no anchor baseline exists for this person + metric.
    func deviationFromAnchor(metric: String, value: Double, personId: UUID) -> Double {
        let k = Self.key(personId: personId, metric: metric)
        guard let baseline = anchorBaselines[k],
              let anchor = baseline.anchorValue else { return 0.0 }
        let window = rollingWindows[k, default: []].map { $0.value }
        let minMAD = minimumMAD[metric] ?? 0.1
        let mad = robustMAD(values: window, reference: anchor, minMAD: minMAD)
        return (value - anchor) / (1.4826 * mad)
    }

    // MARK: - Deviation from Adaptive (robust z-score)
    /// Returns a robust z-score using the rolling adaptive median as reference.
    /// Returns 0 if fewer than 3 observations are available.
    func deviationFromAdaptive(metric: String, value: Double, personId: UUID) -> Double {
        let k = Self.key(personId: personId, metric: metric)
        let window = rollingWindows[k, default: []].map { $0.value }
        guard window.count >= 3 else { return 0.0 }
        let medianVal = median(window)
        let minMAD = minimumMAD[metric] ?? 0.1
        let mad = robustMAD(values: window, reference: medianVal, minMAD: minMAD)
        return (value - medianVal) / (1.4826 * mad)
    }

    // MARK: - Baseline accessors
    func anchorBaseline(for metric: String, personId: UUID) -> Baseline? {
        anchorBaselines[Self.key(personId: personId, metric: metric)]
    }

    func adaptiveBaseline(for metric: String, personId: UUID) -> Baseline? {
        adaptiveBaselines[Self.key(personId: personId, metric: metric)]
    }

    func allBaselines(for personId: UUID) -> [Baseline] {
        let anchorValues = anchorBaselines.values.filter { $0.personId == personId }
        let adaptiveValues = adaptiveBaselines.values.filter { $0.personId == personId }
        return (anchorValues + adaptiveValues).sorted { $0.metric < $1.metric }
    }

    // MARK: - Private helpers
    private static func key(personId: UUID, metric: String) -> String {
        "\(personId.uuidString)-\(metric)"
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }

    private func robustMAD(values: [Double], reference: Double, minMAD: Double) -> Double {
        guard !values.isEmpty else { return minMAD }
        let deviations = values.map { abs($0 - reference) }
        let mad = median(deviations)
        return max(mad, minMAD)
    }
}
