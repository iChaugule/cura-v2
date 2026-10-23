import SwiftUI

struct HydrationLogView: View {
    @Bindable var log: DailyCareLog
    @State private var customAmount: String = ""
    @State private var showCustomEntry = false
    @State private var selectedSigns: Set<HydrationSigns> = [.noneObserved]
    @Environment(\.dismiss) private var dismiss

    private var hydration: HydrationLog {
        log.hydrationLog ?? HydrationLog(entries: [], refusalCount: 0, signs: [], baselineML: 1100, recordedAt: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    totalTallyCard
                    quickAddRow
                    entriesSection
                    refusalSection
                    hydrationSignsSection
                    guidanceCard
                    voiceNoteButton
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.careBodyMedium)
                        .foregroundStyle(.careAccentBlue)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.textSecondary)
                }
            }
        }
    }

    // MARK: - Total Tally Card

    private var totalTallyCard: some View {
        CareCard {
            VStack(spacing: Spacing.sm) {
                HStack {
                    Text("Today's total")
                        .font(.careHeading)
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("\(hydration.totalML) mL")
                        .font(.careDisplayMedium)
                        .foregroundStyle(tallyColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .fill(Color.surfaceDepressed)
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .fill(tallyColor)
                            .frame(width: geo.size.width * min(Double(hydration.totalML) / Double(hydration.baselineML), 1.0), height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("0 mL")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Text("Usual: \(hydration.baselineML) mL")
                        .font(.careCaption)
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(Spacing.md)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hydration total: \(hydration.totalML) mL of \(hydration.baselineML) mL baseline")
    }

    private var tallyColor: Color {
        let ratio = Double(hydration.totalML) / Double(max(hydration.baselineML, 1))
        if ratio >= 0.9 { return .carePositive }
        if ratio >= 0.6 { return .careAttention }
        return .careUrgent
    }

    // MARK: - Quick Add Row

    private var quickAddRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Quick add")
                .font(.careHeading)
                .foregroundStyle(.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach([("+ 100 mL", 100), ("+ 150 mL", 150), ("+ 200 mL", 200),
                             ("+ 250 mL", 250), ("One cup", 200), ("One glass", 300)], id: \.0) { label, amount in
                        Button {
                            addEntry(amount: amount, description: label)
                        } label: {
                            Text(label)
                                .font(.careBodyMedium)
                                .foregroundStyle(.careAccentBlue)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(Color.careAccentBlue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("Add \(amount) millilitres")
                    }

                    Button {
                        showCustomEntry = true
                    } label: {
                        Text("Custom")
                            .font(.careBodyMedium)
                            .foregroundStyle(.curaTeal)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.curaTeal.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .frame(minHeight: 44)
                    .accessibilityLabel("Enter custom amount")
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.horizontal, -Spacing.md)
        }
    }

    // MARK: - Entries

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Drinks recorded today")

            if hydration.entries.isEmpty {
                CareCard {
                    Text("No drinks recorded yet. Use the quick-add buttons above.")
                        .font(.careBody)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(hydration.entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.description.isEmpty ? "Drink" : entry.description)
                                    .font(.careBodyMedium)
                                    .foregroundStyle(.textPrimary)
                                Text(entry.time, style: .time)
                                    .font(.careCaption)
                                    .foregroundStyle(.textSecondary)
                            }
                            Spacer()
                            Text("\(entry.amountML) mL")
                                .font(.careBodyMedium)
                                .foregroundStyle(.careAccentBlue)
                        }
                        .padding(Spacing.md)
                        .background(Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.description), \(entry.amountML) millilitres at \(entry.time.formatted(date: .omitted, time: .shortened))")
                    }
                }
            }
        }
    }

    // MARK: - Refusals

    private var refusalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Fluid refusals")

            CareCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Times she declined fluids")
                            .font(.careBodyMedium)
                            .foregroundStyle(.textPrimary)
                        Text("Count of refusals during this visit")
                            .font(.careCaption)
                            .foregroundStyle(.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: Spacing.md) {
                        Button {
                            if hydration.refusalCount > 0 {
                                updateRefusalCount(hydration.refusalCount - 1)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(hydration.refusalCount > 0 ? .careAttention : .textSecondary)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Decrease refusal count")

                        Text("\(hydration.refusalCount)")
                            .font(.curaLarge)
                            .foregroundStyle(.textPrimary)
                            .frame(minWidth: 32)

                        Button {
                            updateRefusalCount(hydration.refusalCount + 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.careAccentBlue)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Increase refusal count")
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: - Hydration Signs

    private var hydrationSignsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Signs observed")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
                ForEach(HydrationSigns.allCases, id: \.self) { sign in
                    Button {
                        toggleSign(sign)
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: selectedSigns.contains(sign) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedSigns.contains(sign) ? .careAccentBlue : .textSecondary)
                            Text(sign.rawValue)
                                .font(.careBody)
                                .foregroundStyle(.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .frame(minHeight: 44)
                        .background(selectedSigns.contains(sign) ? Color.careAccentBlue.opacity(0.08) : Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(sign.rawValue)
                    .accessibilityAddTraits(selectedSigns.contains(sign) ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Guidance Card

    private var guidanceCard: some View {
        CareCard {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.careAccentBlue)
                    .font(.body)
                Text("Offer fluids in her preferred cups and at preferred times. If intake stays consistently low, contact the care team — do not force fluids.")
                    .font(.careBody)
                    .foregroundStyle(.textSecondary)
            }
            .padding(Spacing.md)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Guidance: Offer fluids in preferred cups. If intake stays low, contact the care team. Do not force fluids.")
    }

    // MARK: - Voice Note

    private var voiceNoteButton: some View {
        Button {
            // Voice note recording
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.careAccentTeal)
                Text("Add voice note")
                    .font(.careBodyMedium)
                    .foregroundStyle(.careAccentTeal)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.careAccentTeal.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .accessibilityLabel("Add voice note about hydration")
    }

    // MARK: - Actions

    private func addEntry(amount: Int, description: String) {
        var h = hydration
        h.entries.append(HydrationEntry(time: Date(), amountML: amount, description: description))
        log.hydrationLog = h
    }

    private func updateRefusalCount(_ count: Int) {
        var h = hydration
        h.refusalCount = count
        log.hydrationLog = h
    }

    private func toggleSign(_ sign: HydrationSigns) {
        if sign == .noneObserved {
            selectedSigns = [.noneObserved]
        } else {
            selectedSigns.remove(.noneObserved)
            if selectedSigns.contains(sign) {
                selectedSigns.remove(sign)
                if selectedSigns.isEmpty { selectedSigns = [.noneObserved] }
            } else {
                selectedSigns.insert(sign)
            }
        }
        var h = hydration
        h.signs = Array(selectedSigns)
        log.hydrationLog = h
    }

    private func save() {
        if log.hydrationLog == nil {
            log.hydrationLog = HydrationLog(entries: hydration.entries, refusalCount: hydration.refusalCount,
                                            signs: hydration.signs, baselineML: hydration.baselineML, recordedAt: Date())
        }
        dismiss()
    }
}

#Preview {
    HydrationLogView(log: SampleData.dailyCareLog)
}
