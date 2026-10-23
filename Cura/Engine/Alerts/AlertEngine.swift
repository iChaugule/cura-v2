import Foundation
import Observation

// MARK: - AlertEngine
@Observable
@MainActor
final class AlertEngine {

    private let clusterMatcher = ClusterMatcher()
    private let cusumDetector = CUSUMDetector()

    // MARK: - Evaluate
    /// Runs all alert layers and returns a deduplicated, sorted array of ConcernAlerts.
    ///
    /// - Parameters:
    ///   - personId: The subject of care being evaluated.
    ///   - observations: All available observations for this person.
    ///   - baselines: Current baselines for this person.
    ///   - contextEvents: Contextual events (med changes, illnesses, travel) that may explain signals.
    func evaluate(
        personId: UUID,
        observations: [Observation],
        baselines: [Baseline],
        contextEvents: [ContextEvent]
    ) -> [ConcernAlert] {
        var alerts: [ConcernAlert] = []

        // Layer 0 – Red flag rules
        let redFlagAlerts = evaluateRedFlags(personId: personId, observations: observations)
        alerts.append(contentsOf: redFlagAlerts)

        // Layer 1 – Cluster matching
        let clusterAlerts = evaluateClusters(
            personId: personId,
            observations: observations,
            baselines: baselines,
            contextEvents: contextEvents
        )
        alerts.append(contentsOf: clusterAlerts)

        // Layer 2 – CUSUM on hydration
        if let cusumAlert = evaluateHydrationCUSUM(personId: personId, observations: observations) {
            alerts.append(cusumAlert)
        }

        // Deduplicate: if the same cluster / rule already has a non-acknowledged alert
        // for the same episode, keep only the most recent.
        let deduplicated = deduplicate(alerts)

        return deduplicated.sorted { lhs, rhs in
            tierPriority(lhs.tier) > tierPriority(rhs.tier)
        }
    }

    // MARK: - Layer 0: Red Flag Rules
    private func evaluateRedFlags(personId: UUID, observations: [Observation]) -> [ConcernAlert] {
        var alerts: [ConcernAlert] = []
        let recentCutoff = Date().addingTimeInterval(-48 * 3600)
        let recent = observations.filter { $0.personId == personId && $0.timestamp >= recentCutoff }

        for obs in recent {
            // Fall with possible injury
            if obs.category == .mobility &&
               obs.qualitativeValue == FallType.fallWithPossibleInjury.rawValue {
                alerts.append(makeAlert(
                    personId: personId,
                    tier: .urgent,
                    headline: "Fall with possible injury reported",
                    detail: "A fall with possible injury was recorded at \(formattedTime(obs.timestamp)). Immediate assessment is recommended.",
                    supportingIds: [obs.id],
                    alternatives: ["Caregiver may have been overly cautious in assessment"],
                    confidence: "High — direct caregiver observation",
                    missing: ["Was there any loss of consciousness?", "Is there visible bruising or swelling?"],
                    action: "Contact family immediately. If there is any swelling, bruising, or the person reports pain, seek medical attention.",
                    episodeId: UUID()
                ))
            }

            // Blood in urine (noted in observation text)
            if obs.category == .toileting &&
               (obs.notes.lowercased().contains("blood") || obs.notes.lowercased().contains("pink") || obs.notes.lowercased().contains("red urine")) {
                alerts.append(makeAlert(
                    personId: personId,
                    tier: .urgent,
                    headline: "Blood observed in urine",
                    detail: "Caregiver noted possible blood in urine at \(formattedTime(obs.timestamp)). This requires prompt medical review.",
                    supportingIds: [obs.id],
                    alternatives: ["Dietary factors (beetroot, certain medications) can cause urine discolouration"],
                    confidence: "Moderate — single caregiver observation",
                    missing: ["Was there any associated pain?", "Has she been taking any new medications?"],
                    action: "Contact the doctor within the hour. Do not wait for next scheduled visit.",
                    episodeId: UUID()
                ))
            }

            // Unresponsive
            if obs.notes.lowercased().contains("unrespons") || obs.notes.lowercased().contains("not waking") {
                alerts.append(makeAlert(
                    personId: personId,
                    tier: .urgent,
                    headline: "Unresponsiveness reported",
                    detail: "Caregiver noted possible unresponsiveness at \(formattedTime(obs.timestamp)). This requires immediate emergency assessment.",
                    supportingIds: [obs.id],
                    alternatives: ["Deep sleep or medication sedation may mimic unresponsiveness"],
                    confidence: "High — immediate action required regardless",
                    missing: [],
                    action: "Call emergency services (112) immediately if the person cannot be roused.",
                    episodeId: UUID()
                ))
            }

            // Seizure
            if obs.notes.lowercased().contains("seizure") || obs.notes.lowercased().contains("convuls") {
                alerts.append(makeAlert(
                    personId: personId,
                    tier: .urgent,
                    headline: "Possible seizure activity observed",
                    detail: "A possible seizure was reported at \(formattedTime(obs.timestamp)). Emergency medical evaluation is required.",
                    supportingIds: [obs.id],
                    alternatives: ["Myoclonic jerks during sleep may be mistaken for seizure activity"],
                    confidence: "Moderate — caregiver observation",
                    missing: ["How long did the episode last?", "Did she lose consciousness?"],
                    action: "Seek emergency care immediately. Do not leave her alone.",
                    episodeId: UUID()
                ))
            }

            // Choking
            if obs.category == .food &&
               obs.notes.lowercased().contains("chok") {
                alerts.append(makeAlert(
                    personId: personId,
                    tier: .urgent,
                    headline: "Choking episode during meal",
                    detail: "A choking episode was noted during a meal at \(formattedTime(obs.timestamp)). Swallowing safety review recommended.",
                    supportingIds: [obs.id],
                    alternatives: ["Coughing during eating can be a normal response to food going down the wrong way"],
                    confidence: "Moderate — context determines severity",
                    missing: ["Did the episode resolve on its own?", "Was any intervention required?"],
                    action: "Consult a speech-language pathologist regarding swallowing safety. Update texture modification instructions if needed.",
                    episodeId: UUID()
                ))
            }

            // Fever
            if obs.category == .vitals, obs.metric == "temperature" {
                if let temp = obs.numericValue, temp >= 38.5 {
                    alerts.append(makeAlert(
                        personId: personId,
                        tier: .urgent,
                        headline: "High fever recorded — \(String(format: "%.1f", temp))°C",
                        detail: "Temperature of \(String(format: "%.1f", temp))°C recorded at \(formattedTime(obs.timestamp)). This warrants immediate medical assessment.",
                        supportingIds: [obs.id],
                        alternatives: ["Thermometer calibration error or incorrect measurement technique"],
                        confidence: "High if measurement is accurate",
                        missing: ["Was the temperature confirmed with a second reading?", "Any other symptoms such as shivering or rash?"],
                        action: "Contact the doctor immediately. Monitor temperature every 30 minutes. Ensure adequate hydration.",
                        episodeId: UUID()
                    ))
                }
            }

            // Missing person / exit-seeking with access concerns
            if obs.category == .mood,
               obs.notes.lowercased().contains("missing") || obs.notes.lowercased().contains("left home") || obs.notes.lowercased().contains("exit seek") {
                alerts.append(makeAlert(
                    personId: personId,
                    tier: .urgent,
                    headline: "Potential exit-seeking or missing person concern",
                    detail: "Caregiver noted possible exit-seeking behaviour or a concern about the person's whereabouts at \(formattedTime(obs.timestamp)).",
                    supportingIds: [obs.id],
                    alternatives: ["Wandering within the home may have been mistaken for exit attempt"],
                    confidence: "Moderate — depends on home safety setup",
                    missing: ["Are all door alarms and safety latches in place?", "Has the person been located?"],
                    action: "Confirm person's location immediately. Ensure all exits are secured. Notify family.",
                    episodeId: UUID()
                ))
            }
        }

        return alerts
    }

    // MARK: - Layer 1: Cluster Matching
    private func evaluateClusters(
        personId: UUID,
        observations: [Observation],
        baselines: [Baseline],
        contextEvents: [ContextEvent]
    ) -> [ConcernAlert] {
        let personObs = observations.filter { $0.personId == personId }
        let personBaselines = baselines.filter { $0.personId == personId }
        let matches = clusterMatcher.evaluate(observations: personObs, baselines: personBaselines)

        return matches.map { match in
            let episodeId = UUID()
            let contextNote = contextEvents.isEmpty ? "" : " Recent context: \(contextEvents.map { "\($0.type.rawValue): \($0.note)" }.joined(separator: "; "))."
            return makeAlert(
                personId: personId,
                tier: match.tier,
                headline: headlineFor(cluster: match.clusterName),
                detail: detailFor(cluster: match.clusterName, score: match.weightedScore, signals: match.matchedSignals) + contextNote,
                supportingIds: [],
                alternatives: alternativesFor(cluster: match.clusterName, contextEvents: contextEvents),
                confidence: confidenceFor(score: match.weightedScore),
                missing: match.missingInfo,
                action: actionFor(cluster: match.clusterName, tier: match.tier),
                episodeId: episodeId
            )
        }
    }

    // MARK: - Layer 2: CUSUM Hydration
    private func evaluateHydrationCUSUM(personId: UUID, observations: [Observation]) -> ConcernAlert? {
        let hydrationObs = observations
            .filter { $0.personId == personId && $0.category == .hydration && $0.numericValue != nil }
            .sorted { $0.timestamp < $1.timestamp }
        guard hydrationObs.count >= 5 else { return nil }

        let series = hydrationObs.compactMap { obs -> (date: Date, value: Double)? in
            guard let v = obs.numericValue else { return nil }
            return (date: obs.timestamp, value: v)
        }
        let result = cusumDetector.detect(values: series, targetDelta: 300, slack: 0.5)
        guard result.isSignificant && result.negativeSum > result.positiveSum else { return nil }

        return makeAlert(
            personId: personId,
            tier: .monitorClosely,
            headline: "Sustained drop in daily fluid intake detected",
            detail: "Statistical analysis of fluid intake over the past \(series.count) recorded days shows a sustained downward trend. This pattern began around \(result.firstSignificantDate.map { formattedDate($0) } ?? "recently").",
            supportingIds: hydrationObs.map(\.id),
            alternatives: [
                "Measurement variability (caregiver estimations may differ day to day)",
                "Short-term illness or reduced thirst during cooler weather"
            ],
            confidence: "Moderate — based on \(series.count) observations",
            missing: [
                "Has she complained of dry mouth or reduced thirst?",
                "Are there any new medications that could reduce thirst?"
            ],
            action: "Review hydration strategies. Consider offering preferred fluids more frequently. Mention to the doctor at next visit if the trend continues.",
            episodeId: UUID()
        )
    }

    // MARK: - Deduplication
    private func deduplicate(_ alerts: [ConcernAlert]) -> [ConcernAlert] {
        var seen: [String: ConcernAlert] = [:]
        for alert in alerts.sorted(by: { $0.createdAt > $1.createdAt }) {
            let key = alert.headline
            if seen[key] == nil {
                seen[key] = alert
            }
        }
        return Array(seen.values)
    }

    // MARK: - Helpers
    private func makeAlert(
        personId: UUID,
        tier: AlertTier,
        headline: String,
        detail: String,
        supportingIds: [UUID],
        alternatives: [String],
        confidence: String,
        missing: [String],
        action: String,
        episodeId: UUID
    ) -> ConcernAlert {
        ConcernAlert(
            tier: tier,
            headline: headline,
            detail: detail,
            domain: "general",
            recommendedAction: action,
            alternativeExplanations: alternatives,
            missingInformation: missing,
            confidence: confidence,
            confidenceReason: "",
            createdAt: Date(),
            updatedAt: Date(),
            supportingObservationSummaries: []
        )
    }

    private func tierPriority(_ tier: AlertTier) -> Int {
        switch tier {
        case .urgent:        return 4
        case .contactCare:   return 3
        case .monitorClosely:       return 2
        case .informational: return 1
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func headlineFor(cluster: String) -> String {
        switch cluster {
        case "possibleDehydration": return "Signs of possible dehydration"
        case "possibleInfection":   return "Signs consistent with possible infection"
        default:                    return "Pattern detected: \(cluster)"
        }
    }

    private func detailFor(cluster: String, score: Double, signals: [String]) -> String {
        let signalList = signals.joined(separator: ", ")
        switch cluster {
        case "possibleDehydration":
            return "Multiple hydration-related observations are below expected levels. Matched signals: \(signalList). Pattern confidence score: \(String(format: "%.0f", score * 100))%."
        case "possibleInfection":
            return "A combination of behavioural and physical observations may indicate an underlying infection. Matched signals: \(signalList). Pattern confidence score: \(String(format: "%.0f", score * 100))%."
        default:
            return "Signals matched: \(signalList). Score: \(String(format: "%.0f", score * 100))%."
        }
    }

    private func alternativesFor(cluster: String, contextEvents: [ContextEvent]) -> [String] {
        var alts: [String]
        switch cluster {
        case "possibleDehydration":
            alts = [
                "Hot weather or increased physical activity may explain short-term fluid loss",
                "Caregiver documentation variability across shifts"
            ]
        case "possibleInfection":
            alts = [
                "New medication started recently may cause behavioural side effects",
                "Environmental change or disrupted routine can mimic infection symptoms"
            ]
        default:
            alts = []
        }
        for event in contextEvents where event.type == .medicationChange {
            alts.append("New medication (\(event.note)) may be contributing to the observed pattern.")
        }
        return alts
    }

    private func confidenceFor(score: Double) -> String {
        if score >= 0.7 { return "Moderate–High — multiple corroborating signals" }
        if score >= 0.45 { return "Moderate — some supporting signals present" }
        return "Low–Moderate — limited supporting evidence"
    }

    private func actionFor(cluster: String, tier: AlertTier) -> String {
        switch cluster {
        case "possibleDehydration":
            return tier == .urgent
                ? "Seek medical attention now. Offer fluids in small, frequent amounts and monitor urine output."
                : "Increase fluid offerings. Track intake carefully over next 24 hours. Mention to family and flag for doctor if intake remains below 800 ml."
        case "possibleInfection":
            return tier == .urgent
                ? "Contact family and doctor immediately. Monitor temperature every 2 hours."
                : "Monitor closely. Take temperature. Contact family if any deterioration. Flag for doctor appointment."
        default:
            return "Review with care coordinator and family."
        }
    }
}
