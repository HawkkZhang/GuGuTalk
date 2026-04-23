import AppKit
import Combine
import SwiftUI

@MainActor
final class PreviewOverlayController {
    private let previewState: PreviewState
    private let panel: NSPanel
    private var cancellables = Set<AnyCancellable>()

    init(previewState: PreviewState) {
        self.previewState = previewState
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 388, height: 188),
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
            rootView: PreviewOverlayView(previewState: previewState)
                .environment(\.colorScheme, .light)
        )
    }

    private func bind() {
        previewState.$isVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in
                guard let self else { return }
                if isVisible {
                    self.show()
                } else {
                    self.panel.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }

    private func show() {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            panel.center()
            panel.orderFrontRegardless()
            return
        }

        let origin = NSPoint(
            x: screenFrame.midX - panel.frame.width / 2,
            y: screenFrame.maxY - panel.frame.height - 54
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }
}

private struct PreviewOverlayView: View {
    @ObservedObject var previewState: PreviewState

    private let surfaceColor = Color(red: 0.965, green: 0.976, blue: 0.995)
    private let cardColor = Color(red: 0.995, green: 0.997, blue: 1.0)
    private let primaryText = Color(red: 0.10, green: 0.14, blue: 0.20)
    private let secondaryText = Color(red: 0.35, green: 0.40, blue: 0.48)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: previewState.menuBarSymbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(previewState.errorMessage == nil ? Color.accentColor : .red)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(previewState.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryText)
                    Text(previewState.message)
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(previewState.activeMode.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.92), in: Capsule())
            }

            if !previewState.transcript.isEmpty {
                Text(previewState.transcript)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(red: 0.84, green: 0.88, blue: 0.95), lineWidth: 1)
                    )
                    .textSelection(.enabled)
            }

            if let errorMessage = previewState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LevelMeter(level: previewState.audioLevel)
            }
        }
        .padding(16)
        .frame(width: 364)
        .background(
            LinearGradient(
                colors: [surfaceColor, Color(red: 0.92, green: 0.95, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 9)
        .padding(8)
    }
}

private struct LevelMeter: View {
    let level: Float

    private let secondaryText = Color(red: 0.35, green: 0.40, blue: 0.48)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("音量")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondaryText)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.21, green: 0.73, blue: 0.63), Color(red: 0.19, green: 0.45, blue: 0.91)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * max(0.05, CGFloat(min(level * 3.2, 1.0))))
                    }
            }
            .frame(height: 10)
        }
    }
}
