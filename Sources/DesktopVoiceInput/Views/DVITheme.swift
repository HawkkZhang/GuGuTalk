import AppKit
import SwiftUI

enum DVITheme {
    static let panelRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
    static let overlayRadius: CGFloat = 23

    static let accent = color(light: (0.16, 0.72, 0.78), dark: (0.45, 0.88, 0.92))
    static let accentStrong = color(light: (0.04, 0.47, 0.53), dark: (0.68, 0.96, 0.98))
    static let accentSoft = color(light: (0.83, 0.97, 0.98), dark: (0.08, 0.23, 0.26))
    static let brandWarm = color(light: (0.95, 0.55, 0.22), dark: (1.00, 0.70, 0.36))
    static let ready = color(light: (0.08, 0.61, 0.44), dark: (0.48, 0.92, 0.70))
    static let caution = color(light: (0.82, 0.43, 0.10), dark: (1.00, 0.69, 0.36))
    static let danger = color(light: (0.84, 0.18, 0.18), dark: (1.00, 0.45, 0.42))
    static let selectedInk = color(light: (0.98, 0.99, 1.00), dark: (0.98, 0.99, 1.00))

    static let ink = color(light: (0.08, 0.13, 0.15), dark: (0.94, 0.97, 0.97))
    static let secondaryInk = color(light: (0.31, 0.42, 0.43), dark: (0.70, 0.79, 0.80))
    static let tertiaryInk = color(light: (0.52, 0.63, 0.64), dark: (0.54, 0.66, 0.67))

    static let window = color(light: (0.94, 0.98, 0.98), dark: (0.06, 0.10, 0.11))
    static let sidebar = color(light: (0.88, 0.97, 0.98), dark: (0.07, 0.17, 0.19))
    static let panel = color(light: (1.00, 0.99, 0.96), dark: (0.12, 0.19, 0.20))
    static let elevatedPanel = color(light: (0.95, 0.99, 0.99), dark: (0.16, 0.25, 0.27))
    static let control = color(light: (0.87, 0.95, 0.96), dark: (0.18, 0.30, 0.32))
    static let controlElevated = color(light: (0.99, 1.00, 0.98), dark: (0.20, 0.31, 0.33))
    static let separator = color(light: (0.63, 0.78, 0.80), dark: (0.33, 0.50, 0.53))
    static let overlaySurface = color(light: (1.00, 0.99, 0.94), dark: (0.10, 0.24, 0.26))
    static let overlayActive = color(light: (0.14, 0.70, 0.76), dark: (0.15, 0.58, 0.63))
    static let overlayInk = color(light: (0.07, 0.16, 0.18), dark: (0.96, 0.99, 0.99))
    static let overlayMutedInk = color(light: (0.36, 0.49, 0.51), dark: (0.70, 0.86, 0.88))
    static let overlayShadow = color(light: (0.04, 0.26, 0.30), dark: (0.00, 0.00, 0.00))

    static func stateFill(_ color: Color, emphasized: Bool = false) -> Color {
        color.opacity(emphasized ? 0.18 : 0.10)
    }

    static func stateStroke(_ color: Color, emphasized: Bool = false) -> Color {
        color.opacity(emphasized ? 0.42 : 0.24)
    }

    static func panelShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
    }

    static func controlShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: controlRadius, style: .continuous)
    }

    static func overlayShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: overlayRadius, style: .continuous)
    }

    static func statusMarkShape() -> RoundedRectangle {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
    }

    private static func color(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let values = isDark ? dark : light
            return NSColor(
                calibratedRed: values.0,
                green: values.1,
                blue: values.2,
                alpha: 1
            )
        })
    }
}

struct DVIChoiceBar<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    var label: (Option) -> String
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.smooth(duration: 0.18)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.system(size: compact ? 11.5 : 12.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? DVITheme.selectedInk : DVITheme.secondaryInk)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, compact ? 8 : 12)
                        .padding(.vertical, compact ? 6 : 8)
                        .background {
                            if isSelected {
                                DVITheme.controlShape()
                                    .fill(
                                        LinearGradient(
                                            colors: [DVITheme.accent, DVITheme.accentStrong],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: DVITheme.accent.opacity(0.20), radius: 7, x: 0, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(DVITheme.control, in: DVITheme.controlShape())
        .overlay(DVITheme.controlShape().stroke(DVITheme.separator.opacity(0.20), lineWidth: 1))
    }
}

struct DVISwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(trackFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(trackStroke, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DVITheme.selectedInk)
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(isOn ? 0.18 : 0.10), radius: 4, x: 0, y: 2)
                    .padding(2)
            }
            .frame(width: 44, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "已开启" : "已关闭")
    }

    private var trackFill: some ShapeStyle {
        LinearGradient(
            colors: isOn
                ? [DVITheme.accent, DVITheme.accentStrong]
                : [DVITheme.control, DVITheme.controlElevated],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var trackStroke: Color {
        isOn ? DVITheme.accentStrong.opacity(0.35) : DVITheme.separator.opacity(0.34)
    }
}

struct DVIAppIcon: View {
    var size: CGFloat = 32

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: DVITheme.overlayShadow.opacity(0.12), radius: 5, x: 0, y: 2)
    }
}
