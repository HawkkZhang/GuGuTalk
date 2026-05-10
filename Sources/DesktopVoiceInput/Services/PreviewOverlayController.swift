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
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        let hostingView = NSHostingView(
            rootView: PreviewOverlayView(previewState: previewState, settings: settings)
                .preferredColorScheme(settings.appearancePreference.colorScheme)
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        panel.contentView = hostingView
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

        Publishers.CombineLatest4(
            previewState.$transcript.removeDuplicates(),
            previewState.$errorMessage.removeDuplicates(),
            previewState.$hintMessage.removeDuplicates(),
            previewState.$isPostProcessing.removeDuplicates()
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
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
            y: screenFrame.minY + 80,
            width: size.width,
            height: size.height
        )
    }

    private static func panelSize(for state: PreviewState) -> NSSize {
        if state.errorMessage != nil {
            return NSSize(width: 292, height: 58)
        }

        if state.hintMessage != nil {
            return NSSize(width: 198, height: 38)
        }

        if state.isPostProcessing {
            return NSSize(width: 140, height: 42)
        }

        let metrics = TranscriptLayoutMetrics(text: state.transcript)
        if metrics.trimmedText.isEmpty {
            return NSSize(width: 126, height: 40)
        }

        let charCount = metrics.trimmedText.count
        let avgCharWidth: CGFloat = 10.6
        let estimatedTextWidth = CGFloat(charCount) * avgCharWidth
        let padding: CGFloat = 58
        let desiredWidth = estimatedTextWidth + padding

        let minWidth: CGFloat = 220
        let maxWidthForLines: CGFloat
        switch metrics.lineCount {
        case 1: maxWidthForLines = 360
        default: maxWidthForLines = 430
        }
        let width = min(max(desiredWidth, minWidth), maxWidthForLines)

        let height: CGFloat
        switch metrics.lineCount {
        case 1: height = 60
        case 2: height = 82
        default: height = 104
        }

        return NSSize(width: width, height: height)
    }
}

private struct PreviewOverlayView: View {
    @ObservedObject var previewState: PreviewState
    @ObservedObject var settings: AppSettings

    private let ready = DVITheme.ready
    private let danger = DVITheme.danger
    private var transcriptMetrics: TranscriptLayoutMetrics {
        TranscriptLayoutMetrics(text: previewState.transcript)
    }
    private var isCompactIsland: Bool {
        previewState.errorMessage != nil ||
            previewState.isPostProcessing ||
            previewState.hintMessage != nil ||
            transcriptMetrics.trimmedText.isEmpty
    }
    private var overlayFill: Color {
        return DVITheme.overlayActive
    }
    private var overlayStroke: Color {
        return Color.clear
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let errorMessage = previewState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(danger)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.tail)
            } else if previewState.isPostProcessing {
                postProcessingIndicator
            } else if let hintMessage = previewState.hintMessage {
                Text(compactHintText(for: hintMessage))
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(DVITheme.selectedInk.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if transcriptMetrics.trimmedText.isEmpty {
                waveform
            } else {
                transcriptContent
            }
        }
        .padding(.horizontal, isCompactIsland ? 13 : 18)
        .padding(.vertical, isCompactIsland ? 8 : 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            DVITheme.overlayShape()
                .fill(overlayFill)
        }
        .overlay {
            DVITheme.overlayShape()
                .stroke(overlayStroke, lineWidth: 0.7)
        }
        .background(Color.clear)
        .clipShape(DVITheme.overlayShape())
        .preferredColorScheme(settings.appearancePreference.colorScheme)
        .animation(.smooth(duration: 0.24), value: previewState.transcript)
        .animation(.smooth(duration: 0.24), value: previewState.errorMessage)
        .animation(.smooth(duration: 0.20), value: previewState.isPostProcessing)
        .animation(.smooth(duration: 0.20), value: previewState.isRecording)
    }

    private func compactHintText(for message: String) -> String {
        if message.contains("没有识别") || message.contains("说话时间太短") {
            return "没有听清"
        }
        return message
    }

    private var waveform: some View {
        WaveformMeter(
            level: previewState.audioLevel,
            tint: transcriptMetrics.trimmedText.isEmpty ? DVITheme.selectedInk : ready,
            isActive: previewState.isRecording,
            isCompact: previewState.transcript.isEmpty
        )
    }

    private var postProcessingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.75)
                .tint(DVITheme.selectedInk)

            Text("处理中")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DVITheme.selectedInk.opacity(0.90))
        }
    }

    private var transcriptContent: some View {
        ZStack(alignment: .center) {
            embeddedWaveform

            RollingTranscriptText(
                text: transcriptMetrics.displayText,
                lineLimit: transcriptMetrics.lineCount,
                color: DVITheme.selectedInk
            )
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var embeddedWaveform: some View {
        Group {
            if previewState.isPostProcessing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.75)
                    .opacity(0.6)
                    .padding(.trailing, 6)
                    .padding(.bottom, 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                WaveformMeter(
                    level: previewState.audioLevel,
                    tint: DVITheme.selectedInk,
                    isActive: previewState.isRecording,
                    isCompact: false
                )
                .scaleEffect(0.92)
                .opacity(0.18)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

}

private struct TranscriptLayoutMetrics {
    private static let singleLineLimit = 24
    private static let doubleLineLimit = 54
    private static let charactersPerLine = 24
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

        let lineCount: Int
        if normalized.count <= Self.singleLineLimit {
            lineCount = 1
        } else if normalized.count <= Self.doubleLineLimit {
            lineCount = 2
        } else {
            lineCount = 3
        }

        let capacity = max(Self.charactersPerLine * lineCount - 2, 1)
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
            .font(.system(size: 14.5, weight: .semibold))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .lineSpacing(3.2)
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
