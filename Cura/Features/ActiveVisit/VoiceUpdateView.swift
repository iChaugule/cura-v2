import SwiftUI
import Observation

enum RecordingState { case idle, recording, paused, processing, done }

@MainActor
@Observable
final class VoiceUpdateViewModel {
    var state: RecordingState = .idle
    var duration: TimeInterval = 0
    var transcript: String = ""
    var translationPreview: String = ""
    var isSubmitting: Bool = false
    private var timerTask: Task<Void, Never>?

    var durationString: String {
        let m = Int(duration) / 60, s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }

    func startRecording() {
        state = .recording
        duration = 0
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { self?.duration += 1 }
            }
        }
    }

    func pauseRecording() {
        timerTask?.cancel()
        state = .paused
    }

    func resumeRecording() {
        state = .recording
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { self?.duration += 1 }
            }
        }
    }

    func stopRecording() async {
        timerTask?.cancel()
        state = .processing
        transcript = ""
        translationPreview = ""
        // Simulate transcription
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        transcript = "Aaji had a good morning. She ate most of her breakfast — upma and chai. Walked with the walker around the building, steady today. Took her tablet after breakfast. No falls or near-falls. Seemed comfortable and recognised me right away."
        translationPreview = "Aaji cha savaar changla gela. Tini nashta kelela — upma ani chai. Walker ghevun imarat phiravali, aaj sthir hoti. Nashtyanantar ti tablet gheuns. Kadhihi padle nahi. Aaram vatle aani lagar mala olgale."
        state = .done
    }

    func retake() {
        timerTask?.cancel()
        state = .idle
        duration = 0
        transcript = ""
        translationPreview = ""
    }

    func submitNote() async {
        isSubmitting = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isSubmitting = false
    }
}

struct VoiceUpdateView: View {
    @Environment(ServiceContainer.self) private var container
    @Environment(AppSession.self) private var session
    @State private var viewModel = VoiceUpdateViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CuraSpacing.xl) {
                    micButton
                    if viewModel.state == .done {
                        transcriptCard
                        translationCard
                        actionButtons
                    }
                    disclaimerText
                }
                .padding(CuraSpacing.md)
                .padding(.bottom, CuraSpacing.xl)
            }
            .background(Color.curaBackground)
            .navigationTitle("Voice Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Mic Button

    private var micButton: some View {
        VStack(spacing: CuraSpacing.lg) {
            ZStack {
                if viewModel.state == .recording {
                    Circle()
                        .fill(Color.curaUrgent.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.state == .recording)
                }
                Button(action: handleMicTap) {
                    Image(systemName: micIcon)
                        .font(.system(size: 50))
                        .foregroundStyle(micColor)
                        .frame(width: 100, height: 100)
                        .background(micColor.opacity(0.12))
                        .clipShape(Circle())
                }
                .frame(width: 100, height: 100)
            }
            .frame(height: 140)

            Text(timerOrStateText)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(viewModel.state == .recording ? .curaUrgent : .secondary)

            if viewModel.state == .recording || viewModel.state == .paused {
                HStack(spacing: CuraSpacing.lg) {
                    Button(action: {
                        if viewModel.state == .recording { viewModel.pauseRecording() }
                        else { viewModel.resumeRecording() }
                    }) {
                        Label(viewModel.state == .paused ? "Resume" : "Pause",
                              systemImage: viewModel.state == .paused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.curaBody)
                            .foregroundStyle(.curaBlue)
                    }
                    .frame(minHeight: 44)

                    Button(action: { Task { await viewModel.stopRecording() } }) {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .font(.curaBody)
                            .foregroundStyle(.curaUrgent)
                    }
                    .frame(minHeight: 44)
                }
            }

            if viewModel.state == .processing {
                HStack(spacing: CuraSpacing.sm) {
                    ProgressView().tint(.curaBlue)
                    Text("Transcribing…").font(.curaBody).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CuraSpacing.lg)
    }

    private var micIcon: String {
        switch viewModel.state {
        case .idle: "mic.circle.fill"
        case .recording: "stop.circle.fill"
        case .paused: "mic.badge.plus"
        case .processing: "waveform.circle"
        case .done: "checkmark.circle.fill"
        }
    }

    private var micColor: Color {
        switch viewModel.state {
        case .idle: .secondary
        case .recording: .curaUrgent
        case .paused: .curaWarning
        case .processing: .curaBlue
        case .done: .curaSuccess
        }
    }

    private var timerOrStateText: String {
        switch viewModel.state {
        case .idle: "Tap to record"
        case .recording, .paused: viewModel.durationString
        case .processing: "Processing…"
        case .done: viewModel.durationString
        }
    }

    private func handleMicTap() {
        switch viewModel.state {
        case .idle: viewModel.startRecording()
        case .recording: Task { await viewModel.stopRecording() }
        default: break
        }
    }

    // MARK: - Waveform Placeholder

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<30, id: \.self) { i in
                Capsule()
                    .fill(Color.curaBlue.opacity(0.6))
                    .frame(width: 3, height: CGFloat.random(in: 8...32))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }

    // MARK: - Transcript Card

    private var transcriptCard: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                HStack {
                    Text("Transcript (English)")
                        .font(.curaHeadline)
                    Spacer()
                    StatusBadge("Machine-generated", color: .secondary)
                }
                waveformView
                Text(viewModel.transcript)
                    .font(.curaBody)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Translation Card

    private var translationCard: some View {
        CareCard {
            VStack(alignment: .leading, spacing: CuraSpacing.sm) {
                HStack {
                    Text("Translation Preview (Marathi)")
                        .font(.curaHeadline)
                    Spacer()
                    Image(systemName: "translate")
                        .foregroundStyle(.curaBlue)
                }
                Text("Shown to family — translated for Raj")
                    .font(.curaCaption).foregroundStyle(.secondary)
                Text(viewModel.translationPreview)
                    .font(.curaBody).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: CuraSpacing.sm) {
            PrimaryButton("Submit to Timeline", icon: "paperplane.fill", isLoading: viewModel.isSubmitting) {
                Task {
                    await viewModel.submitNote()
                    dismiss()
                }
            }
            HStack(spacing: CuraSpacing.sm) {
                Button(action: { viewModel.retake() }) {
                    Label("Retake", systemImage: "arrow.clockwise")
                        .font(.curaBody).foregroundStyle(.curaBlue)
                        .frame(maxWidth: .infinity).frame(minHeight: 48)
                        .background(Color.curaBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                Button(action: { viewModel.retake() }) {
                    Label("Delete", systemImage: "trash")
                        .font(.curaBody).foregroundStyle(.curaUrgent)
                        .frame(maxWidth: .infinity).frame(minHeight: 48)
                        .background(Color.curaUrgent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var disclaimerText: some View {
        Text("Transcript and translation are machine-generated. Original recording is always preserved.")
            .font(.curaCaption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, CuraSpacing.lg)
    }
}

#Preview {
    VoiceUpdateView()
        .environment(ServiceContainer())
        .environment(AppSession())
}
