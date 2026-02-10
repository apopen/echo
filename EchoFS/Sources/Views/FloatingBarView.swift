import SwiftUI

/// Animated floating bar that sits above the dock.
/// Grey pill when idle, voice-reactive blue waveform when recording.
struct FloatingBarView: View {
    @ObservedObject var appState: AppState
    @State private var wavePhase: CGFloat = 0
    @State private var displayLevel: CGFloat = 0
    @State private var timer: Timer?

    // This is the animated state — driven by withAnimation so transitions are smooth.
    @State private var visualState: RecordingState = .idle

    private var isActive: Bool {
        visualState == .recording || visualState == .transcribing
    }

    private var isRecording: Bool {
        visualState == .recording
    }

    private var isTranscribing: Bool {
        visualState == .transcribing
    }

    private var pillWidth: CGFloat { isActive ? 200 : 40 }
    private var pillHeight: CGFloat { isActive ? 32 : 20 }
    private var pillCorner: CGFloat { isActive ? 16 : 10 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: pillCorner)
                .fill(backgroundColor)

            // Idle mic icon — crossfades out
            Image(systemName: "mic.fill")
                .font(.system(size: 8))
                .foregroundColor(.gray.opacity(0.5))
                .opacity(isActive ? 0 : 1)

            // Waveform — crossfades in when recording
            WaveformView(phase: wavePhase, amplitude: displayLevel)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .opacity(isRecording ? 1 : 0)

            // Transcribing dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseScale(for: i))
                }
            }
            .opacity(isTranscribing ? 1 : 0)
        }
        .frame(width: pillWidth, height: pillHeight)
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: appState.recordingState) { newState in
            let wasIdle = visualState == .idle
            let goingIdle = newState == .idle

            let anim: Animation
            if goingIdle {
                // Closing: gentle, cushioned spring
                anim = .spring(response: 0.55, dampingFraction: 0.92)
            } else if wasIdle {
                // Opening: snappy spring with a touch of bounce
                anim = .spring(response: 0.35, dampingFraction: 0.72)
            } else {
                // Between active states (recording ↔ transcribing): smooth crossfade
                anim = .easeInOut(duration: 0.3)
            }

            withAnimation(anim) {
                visualState = newState
            }
        }
    }

    private var backgroundColor: Color {
        switch visualState {
        case .recording:
            return Color.black.opacity(0.85)
        case .transcribing, .inserting:
            return Color(white: 0.1).opacity(0.75)
        default:
            return Color.gray.opacity(0.3)
        }
    }

    private func pulseScale(for index: Int) -> CGFloat {
        let cycle = (wavePhase * 0.5 + CGFloat(index) * 0.7).truncatingRemainder(dividingBy: .pi * 2)
        return 0.7 + 0.6 * abs(sin(cycle))
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                wavePhase += 0.15

                let target = CGFloat(appState.audioLevel)
                if appState.recordingState == .recording {
                    if target > displayLevel {
                        displayLevel = displayLevel * 0.3 + target * 0.7
                    } else {
                        displayLevel = displayLevel * 0.85 + target * 0.15
                    }
                } else {
                    displayLevel = displayLevel * 0.7
                }
            }
        }
    }
}

/// Draws an animated audio waveform driven by actual voice amplitude.
struct WaveformView: View {
    let phase: CGFloat
    let amplitude: CGFloat

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width
            let effectiveAmplitude = max(amplitude, 0.08)

            for wave in 0..<3 {
                let baseAmp = size.height * (0.45 - CGFloat(wave) * 0.08)
                let amp = baseAmp * effectiveAmplitude
                let frequency: CGFloat = 3.0 + CGFloat(wave) * 1.5
                let wavePhase = phase + CGFloat(wave) * 0.8
                let opacity = 0.9 - Double(wave) * 0.25

                var path = Path()
                for x in stride(from: 0, through: width, by: 1) {
                    let normalizedX = x / width
                    let envelope = sin(normalizedX * .pi)
                    let y = midY + sin(normalizedX * frequency * .pi * 2 + wavePhase) * amp * envelope
                    if x == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(Color.blue.opacity(opacity)),
                    lineWidth: 2.0 - CGFloat(wave) * 0.4
                )
            }
        }
    }
}
