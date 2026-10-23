import Foundation

// MARK: - CUSUMResult
struct CUSUMResult: Sendable {
    let positiveSum: Double
    let negativeSum: Double
    let isSignificant: Bool
    let firstSignificantDate: Date?
}

// MARK: - CUSUMDetector
struct CUSUMDetector {
    /// Runs a two-sided CUSUM on a time-ordered series of (date, value) pairs.
    ///
    /// - Parameters:
    ///   - values: Time-ordered observations, oldest first.
    ///   - targetDelta: The minimum shift magnitude worth detecting (in original units).
    ///   - slack: Allowance expressed as a fraction of the estimated sigma.
    ///            Typical value: 0.5 (detect shifts of targetDelta with moderate sensitivity).
    /// - Returns: CUSUMResult with final accumulators, significance flag, and date of first signal.
    func detect(
        values: [(date: Date, value: Double)],
        targetDelta: Double,
        slack: Double
    ) -> CUSUMResult {
        guard values.count >= 4 else {
            return CUSUMResult(
                positiveSum: 0,
                negativeSum: 0,
                isSignificant: false,
                firstSignificantDate: nil
            )
        }

        let rawValues = values.map { $0.value }

        // Estimate mean and sigma from first half of the window (reference period)
        let refCount = max(2, rawValues.count / 2)
        let refValues = Array(rawValues.prefix(refCount))
        let mu = refValues.reduce(0.0, +) / Double(refCount)
        let variance = refValues.map { pow($0 - mu, 2) }.reduce(0.0, +) / Double(refCount)
        let sigma = max(sqrt(variance), targetDelta * 0.01)

        // Allowance k and decision threshold H
        let k = slack * sigma
        let h = 5.0 * sigma

        var sPlus = 0.0
        var sMinus = 0.0
        var firstSignificantDate: Date? = nil

        for entry in values {
            let xi = entry.value
            // Upper CUSUM: detect positive shift
            sPlus = max(0.0, sPlus + xi - mu - k)
            // Lower CUSUM: detect negative shift
            sMinus = max(0.0, sMinus + mu - xi - k)

            if firstSignificantDate == nil && (sPlus > h || sMinus > h) {
                firstSignificantDate = entry.date
            }
        }

        let isSignificant = sPlus > h || sMinus > h
        return CUSUMResult(
            positiveSum: sPlus,
            negativeSum: sMinus,
            isSignificant: isSignificant,
            firstSignificantDate: firstSignificantDate
        )
    }
}
