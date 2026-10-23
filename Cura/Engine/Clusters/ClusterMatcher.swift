import Foundation
import Observation

// MARK: - ClusterConfig
struct ClusterConfig: Codable, Sendable {
    let name: String
    let anchorSignals: [String]
    let supportingSignals: [String: Double]
    let minWeightedScore: Double
    let minDistinctObservers: Int
    let escalateIf: [String]
    let missingInfoPrompts: [String]
}

// MARK: - ClusterMatch
struct ClusterMatch: Identifiable, Sendable {
    let id: UUID
    let clusterName: String
    let weightedScore: Double
    let matchedSignals: [String]
    let tier: AlertTier
    let missingInfo: [String]
}

// MARK: - ClusterMatcher
@Observable
@MainActor
final class ClusterMatcher {

    // MARK: - Hardcoded clusters
    let clusters: [ClusterConfig] = [
        ClusterConfig(
            name: "possibleDehydration",
            anchorSignals: ["low_hydration_intake"],
            supportingSignals: [
                "dry_mouth":          0.35,
                "dark_urine":         0.40,
                "reduced_urination":  0.35,
                "fatigue_noted":      0.20,
                "hydration_refusal":  0.30
            ],
            minWeightedScore: 0.35,
            minDistinctObservers: 1,
            escalateIf: ["fallEvent", "reduced_consciousness", "rapid_heart_rate"],
            missingInfoPrompts: [
                "Has she had additional fluids from family members between visits?",
                "Was she unwell or had a fever in the past 48 hours?",
                "Is there any evidence of vomiting or diarrhoea?"
            ]
        ),
        ClusterConfig(
            name: "possibleInfection",
            anchorSignals: ["sudden_behavior_change", "elevated_confusion"],
            supportingSignals: [
                "fever_noted":          0.50,
                "reduced_appetite":     0.30,
                "unusual_fatigue":      0.30,
                "pain_reported":        0.30,
                "urinary_symptoms":     0.40,
                "increased_sleepiness": 0.25
            ],
            minWeightedScore: 0.45,
            minDistinctObservers: 1,
            escalateIf: ["fever_above_38_5", "refusal_to_wake", "shortness_of_breath"],
            missingInfoPrompts: [
                "Has her temperature been taken recently?",
                "Any changes in urine colour, odour, or frequency?",
                "Did she complain of pain when asked directly?"
            ]
        )
    ]

    // MARK: - Evaluate
    /// Evaluates recent observations against all cluster configs.
    /// Considers observations from the last 72 hours.
    func evaluate(observations: [Observation], baselines: [Baseline]) -> [ClusterMatch] {
        let lookbackSeconds: TimeInterval = 72 * 3600
        let cutoff = Date().addingTimeInterval(-lookbackSeconds)
        let recent = observations.filter { $0.timestamp >= cutoff }

        var matches: [ClusterMatch] = []

        for config in clusters {
            if let match = evaluateCluster(config, recent: recent, baselines: baselines) {
                matches.append(match)
            }
        }
        return matches
    }

    // MARK: - Private
    private func evaluateCluster(
        _ config: ClusterConfig,
        recent: [Observation],
        baselines: [Baseline]
    ) -> ClusterMatch? {
        let signals = extractSignals(from: recent, baselines: baselines)
        let observerIds = Set(recent.map { $0.observerId })

        // Check anchor signals — at least one must be present
        let anchorPresent = config.anchorSignals.contains { signals.contains($0) }
        guard anchorPresent else { return nil }

        // Observer count gate
        guard observerIds.count >= config.minDistinctObservers else { return nil }

        // Weighted score from supporting signals
        var score = 0.0
        var matchedSignals: [String] = config.anchorSignals.filter { signals.contains($0) }

        for (signal, weight) in config.supportingSignals {
            if signals.contains(signal) {
                score += weight
                matchedSignals.append(signal)
            }
        }

        guard score >= config.minWeightedScore else { return nil }

        // Tier escalation
        let escalated = config.escalateIf.contains { signals.contains($0) }
        let tier: AlertTier = escalated ? .urgent : (score >= 0.6 ? .contactCare : .monitorClosely)

        // Missing info: prompts where corresponding signal was not found
        let missingInfo = config.missingInfoPrompts

        return ClusterMatch(
            id: UUID(),
            clusterName: config.name,
            weightedScore: score,
            matchedSignals: matchedSignals,
            tier: tier,
            missingInfo: missingInfo
        )
    }

    /// Translates raw observations into a set of signal tag strings.
    private func extractSignals(from observations: [Observation], baselines: [Baseline]) -> Set<String> {
        var signals = Set<String>()

        for obs in observations {
            switch obs.category {
            case .hydration:
                if let ml = obs.numericValue, ml < 600 {
                    signals.insert("low_hydration_intake")
                }
                if obs.qualitativeValue.lowercased().contains("refus") {
                    signals.insert("hydration_refusal")
                }
                if obs.notes.lowercased().contains("dark urine") || obs.qualitativeValue.lowercased().contains("dark") {
                    signals.insert("dark_urine")
                }
                if obs.notes.lowercased().contains("reduced urin") || obs.notes.lowercased().contains("less urin") {
                    signals.insert("reduced_urination")
                }
                if obs.notes.lowercased().contains("dry mouth") {
                    signals.insert("dry_mouth")
                }

            case .mobility:
                if obs.qualitativeValue == MobilityOverall.noticeablyMoreHelpNeeded.rawValue ||
                   obs.qualitativeValue == MobilityOverall.alittleMoreHelpNeeded.rawValue {
                    signals.insert("mobility_decline")
                }
                if obs.notes.lowercased().contains("fatigue") || obs.notes.lowercased().contains("tired") {
                    signals.insert("fatigue_noted")
                }

            case .mood:
                if [MoodState.agitated.rawValue, MoodState.suspicious.rawValue,
                    MoodState.restless.rawValue].contains(obs.qualitativeValue) {
                    signals.insert("sudden_behavior_change")
                }
                if obs.qualitativeValue == MoodState.withdrawn.rawValue ||
                   obs.qualitativeValue == MoodState.agitated.rawValue {
                    signals.insert("elevated_confusion")
                }

            case .vitals:
                if obs.metric == "temperature", let temp = obs.numericValue {
                    if temp >= 38.0 { signals.insert("fever_noted") }
                    if temp >= 38.5 { signals.insert("fever_above_38_5") }
                }
                if obs.metric == "heart_rate", let hr = obs.numericValue, hr > 100 {
                    signals.insert("rapid_heart_rate")
                }

            case .food:
                if [MealIntake.aFewBites.rawValue, MealIntake.refused.rawValue].contains(obs.qualitativeValue) {
                    signals.insert("reduced_appetite")
                }

            case .sleep:
                if [SleepQuality.barelySleep.rawValue, SleepQuality.wokeFrequently.rawValue].contains(obs.qualitativeValue) {
                    signals.insert("increased_sleepiness")
                }

            case .pain:
                signals.insert("pain_reported")

            case .toileting:
                if obs.notes.lowercased().contains("urin") {
                    signals.insert("urinary_symptoms")
                }

            case .context:
                if obs.notes.lowercased().contains("fatigue") || obs.notes.lowercased().contains("tired") {
                    signals.insert("unusual_fatigue")
                }
                if obs.notes.lowercased().contains("unrespons") {
                    signals.insert("reduced_consciousness")
                }

            default:
                break
            }
        }

        return signals
    }
}
