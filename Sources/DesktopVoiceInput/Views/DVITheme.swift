import AppKit
import SwiftUI

enum DVITheme {
    static let panelRadius: CGFloat = 10
    static let controlRadius: CGFloat = 7
    static let overlayRadius: CGFloat = 12

    static let accent = color(light: (0.00, 0.40, 0.84), dark: (0.38, 0.70, 1.00))
    static let ready = color(light: (0.00, 0.48, 0.31), dark: (0.25, 0.82, 0.55))
    static let caution = color(light: (0.72, 0.42, 0.00), dark: (0.98, 0.66, 0.20))
    static let danger = color(light: (0.76, 0.16, 0.22), dark: (1.00, 0.38, 0.43))

    static let ink = color(light: (0.12, 0.13, 0.15), dark: (0.92, 0.93, 0.94))
    static let secondaryInk = color(light: (0.36, 0.38, 0.42), dark: (0.68, 0.70, 0.74))
    static let tertiaryInk = color(light: (0.52, 0.54, 0.58), dark: (0.54, 0.57, 0.62))

    static let window = color(light: (0.95, 0.95, 0.96), dark: (0.12, 0.12, 0.13))
    static let panel = color(light: (0.99, 0.99, 0.99), dark: (0.17, 0.17, 0.18))
    static let elevatedPanel = color(light: (0.97, 0.97, 0.98), dark: (0.21, 0.21, 0.22))
    static let control = color(light: (0.91, 0.91, 0.93), dark: (0.26, 0.26, 0.28))
    static let separator = color(light: (0.74, 0.75, 0.78), dark: (0.42, 0.43, 0.46))

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
