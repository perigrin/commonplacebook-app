// ABOUTME: Animated waveform visualization for audio recording feedback
// ABOUTME: Displays animated bars that respond to audio level with smooth transitions

import SwiftUI

struct WaveformView: View {
    @Binding var isRecording: Bool
    @Binding var audioLevel: Float

    var waveformColor: Color = .blue
    private let barCount = 40
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 60

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    audioLevel: audioLevel,
                    index: index,
                    totalBars: barCount,
                    minHeight: minBarHeight,
                    maxHeight: maxBarHeight,
                    color: waveformColor,
                    isRecording: isRecording
                )
            }
        }
        .frame(height: maxBarHeight)
        .opacity(isRecording ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}

// MARK: - Waveform Bar

private struct WaveformBar: View {
    let audioLevel: Float
    let index: Int
    let totalBars: Int
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let color: Color
    let isRecording: Bool

    @State private var animatedHeight: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3, height: animatedHeight)
            .onChange(of: audioLevel) { _, newLevel in
                updateHeight(for: newLevel)
            }
            .onChange(of: isRecording) { _, recording in
                if !recording {
                    withAnimation(.easeOut(duration: 0.3)) {
                        animatedHeight = minHeight
                    }
                }
            }
            .onAppear {
                updateHeight(for: audioLevel)
            }
    }

    private func updateHeight(for level: Float) {
        guard isRecording else {
            animatedHeight = minHeight
            return
        }

        // Create a wave pattern across the bars
        let normalizedIndex = Double(index) / Double(totalBars)
        let wave = sin(normalizedIndex * .pi * 2) * 0.5 + 0.5

        // Combine audio level with wave pattern
        let combinedLevel = CGFloat(level) * (0.7 + wave * 0.3)

        // Calculate target height
        let targetHeight = minHeight + (maxHeight - minHeight) * combinedLevel

        // Animate to target height
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            animatedHeight = targetHeight
        }
    }
}

// MARK: - Previews

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Recording with low level
            PreviewWrapper(isRecording: true, audioLevel: 0.2)
                .previewDisplayName("Recording - Low")

            // Recording with medium level
            PreviewWrapper(isRecording: true, audioLevel: 0.5)
                .previewDisplayName("Recording - Medium")

            // Recording with high level
            PreviewWrapper(isRecording: true, audioLevel: 0.9)
                .previewDisplayName("Recording - High")

            // Not recording
            PreviewWrapper(isRecording: false, audioLevel: 0.0)
                .previewDisplayName("Not Recording")

            // Custom color
            PreviewWrapper(isRecording: true, audioLevel: 0.7, color: .green)
                .previewDisplayName("Custom Color")
        }
        .padding()
    }

    struct PreviewWrapper: View {
        @State var isRecording: Bool
        @State var audioLevel: Float
        var color: Color = .blue

        var body: some View {
            VStack {
                Text(isRecording ? "Recording: \(Int(audioLevel * 100))%" : "Not Recording")
                    .font(.caption)
                    .foregroundColor(.secondary)

                WaveformView(
                    isRecording: $isRecording,
                    audioLevel: $audioLevel,
                    waveformColor: color
                )

                if isRecording {
                    HStack {
                        Button("Low") {
                            audioLevel = 0.2
                        }
                        Button("Medium") {
                            audioLevel = 0.5
                        }
                        Button("High") {
                            audioLevel = 0.9
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(uiColor: .systemBackground))
            #endif
            .cornerRadius(12)
        }
    }
}
