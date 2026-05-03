import AppKit
import Combine
import SwiftUI

@MainActor
final class PreviewOverlayController {
    private let previewState: PreviewState
    private let settings: AppSettings
    private let panel: NSPanel
    private var cancellables = Set<AnyCancellable>()
    private var currentPanelSize: NSSize = .zero

    init(previewState: PreviewState, settings: AppSettings) {
        self.previewState = previewState
        self.settings = settings
        self.panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize(for: previewState)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        bind()
    }

    private func configurePanel() {
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.contentView = NSHostingView(
            rootView: PreviewOverlayView(previewState: previewState, settings: settings)
                .preferredColorScheme(settings.appearancePreference.colorScheme)
        )
    }

    private func bind() {
        previewState.$isVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in
                guard let self else { return }
                if isVisible {
                    self.show(animated: false)
                } else {
                    self.panel.orderOut(nil)
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(previewState.$transcript.removeDuplicates(), previewState.$errorMessage.removeDuplicates(), previewState.$hintMessage.removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                guard let self, self.previewState.isVisible else { return }
                self.updateFrame(animated: true)
            }
            .store(in: &cancellables)
    }

    private func show(animated: Bool) {
        updateFrame(animated: animated)
        panel.orderFrontRegardless()
    }

    private func updateFrame(animated: Bool) {
        let size = Self.panelSize(for: previewState)
        let sizeDidChange = abs(size.width - currentPanelSize.width) > 0.5 || abs(size.height - currentPanelSize.height) > 0.5
        guard sizeDidChange || !panel.isVisible else { return }

        let frame = frame(for: size)
        currentPanelSize = size

        if animated, panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func frame(for size: NSSize) -> NSRect {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return NSRect(origin: .zero, size: size)
        }

        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height - 42,
            width: size.width,
            height: size.height
        )
    }

    private static func panelSize(for state: PreviewState) -> NSSize {
        if state.errorMessage != nil {
            return NSSize(width: 300, height: 88)
        }

        if state.hintMessage != nil {
            return NSSize(width: 240, height: 54)
        }

        let metrics = TranscriptLayoutMetrics(text: state.transcript)
        if metrics.trimmedText.isEmpty {
            return NSSize(width: 172, height: 54)
        }

        let charCount = metrics.trimmedText.count
        let avgCharWidth: CGFloat = 11.5
        let estimatedTextWidth = CGFloat(charCount) * avgCharWidth
        let padding: CGFloat = 70
        let desiredWidth = estimatedTextWidth + padding

        let minWidth: CGFloat = 200
        let maxWidthForLines: CGFloat
        switch metrics.lineCount {
        case 1: maxWidthForLines = 340
        case 2: maxWidthForLines = 380
        default: maxWidthForLines = 420
        }
        let width = min(max(desiredWidth, minWidth), maxWidthForLines)

        let height: CGFloat
        switch metrics.lineCount {
        case 1: height = 70
        case 2: height = 98
        default: height = 128
        }

        return NSSize(width: width, height: height)
    }
}

private struct PreviewOverlayView: View {
    @ObservedObject var previewState: PreviewState
    @ObservedObject var settings: AppSettings

    private let primaryText = DVITheme.ink
    private let ready = DVITheme.ready
    private let danger = DVITheme.danger
    private var transcriptMetrics: TranscriptLayoutMetrics {
        TranscriptLayoutMetrics(text: previewState.transcript)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let errorMessage = previewState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(danger)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let hintMessage = previewState.hintMessage {
                Text(hintMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DVITheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            } else if transcriptMetrics.trimmedText.isEmpty {
                waveform
            } else {
                transcriptContent
            }
        }
        .padding(.horizontal, transcriptMetrics.trimmedText.isEmpty ? 12 : 14)
        .padding(.vertical, transcriptMetrics.trimmedText.isEmpty ? 9 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(DVITheme.separator.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 5)
        .padding(5)
        .preferredColorScheme(settings.appearancePreference.colorScheme)
        .animation(.smooth(duration: 0.24), value: previewState.transcript)
        .animation(.smooth(duration: 0.24), value: previewState.errorMessage)
        .animation(.smooth(duration: 0.20), value: previewState.isRecording)
    }

    private var waveform: some View {
        WaveformMeter(
            level: previewState.audioLevel,
            tint: ready,
            isActive: previewState.isRecording,
            isCompact: previewState.transcript.isEmpty
        )
    }

    private var transcriptContent: some View {
        ZStack(alignment: .bottomTrailing) {
            RollingTranscriptText(
                text: transcriptMetrics.displayText,
                lineLimit: transcriptMetrics.lineCount,
                color: primaryText
            )
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .center)

            embeddedWaveform
        }
    }

    private var embeddedWaveform: some View {
        WaveformMeter(
            level: previewState.audioLevel,
            tint: ready,
            isActive: previewState.isRecording,
            isCompact: false
        )
        .scaleEffect(0.90)
        .opacity(0.16)
        .padding(.trailing, 3)
        .padding(.bottom, 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

private struct TranscriptLayoutMetrics {
    private static let charactersPerLine = 21
    let trimmedText: String
    let lineCount: Int
    let displayText: String

    init(text: String) {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        self.trimmedText = normalized

        if normalized.isEmpty {
            self.lineCount = 1
            self.displayText = ""
            return
        }

        let requiredLines = Int(ceil(Double(normalized.count) / Double(Self.charactersPerLine)))
        let lineCount = min(max(requiredLines, 1), 3)
        let capacity = max(Self.charactersPerLine * lineCount - 1, 1)
        self.lineCount = lineCount

        if normalized.count > capacity {
            self.displayText = "…" + String(normalized.suffix(capacity))
        } else {
            self.displayText = normalized
        }
    }
}

private struct RollingTranscriptText: View {
    let text: String
    let lineLimit: Int
    let color: Color

    @State private var blurRadius: CGFloat = 0

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .lineSpacing(2.8)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .center)
            .blur(radius: blurRadius)
            .onChange(of: text) { _, _ in
                blurRadius = 0.65
                withAnimation(.easeOut(duration: 0.18)) {
                    blurRadius = 0
                }
            }
    }
}

private struct WaveformMeter: View {
    let level: Float
    let tint: Color
    let isActive: Bool
    let isCompact: Bool

    var body: some View {
        TimelineView(.animation) { context in
            HStack(alignment: .center, spacing: isCompact ? 3 : 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(tint.opacity(barOpacity(index)))
                        .frame(width: 3, height: barHeight(index, at: context.date))
                }
            }
            .frame(width: isCompact ? 58 : 48, height: isCompact ? 24 : 20)
            .animation(.smooth(duration: 0.18), value: level)
        }
    }

    private var barCount: Int {
        isCompact ? 10 : 8
    }

    private func barHeight(_ index: Int, at date: Date) -> CGFloat {
        let normalized = min(max(CGFloat(level), 0), 1)
        let time = date.timeIntervalSinceReferenceDate
        let phase = CGFloat(time * 5.2) + CGFloat(index) * 0.72
        let motion = isActive ? (sin(phase) + 1) / 2 : 0.18
        let midpoint = CGFloat(barCount - 1) / 2
        let center = 1 - min(abs(CGFloat(index) - midpoint) / max(midpoint, 1), 0.78)
        return 4 + (normalized * (isCompact ? 13 : 11) + motion * (isCompact ? 6 : 5)) * center
    }

    private func barOpacity(_ index: Int) -> Double {
        let normalized = min(max(Double(level), 0), 1)
        let midpoint = Double(barCount - 1) / 2
        let center = 1 - min(abs(Double(index) - midpoint) / max(midpoint, 1), 0.70)
        return 0.30 + normalized * 0.42 + center * 0.22
    }
}
