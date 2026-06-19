import SwiftUI

/// Central color and metric tokens so the whole HUD stays consistent. Tuned
/// for a dark frosted surface.
enum Style {
    // Text
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.55)
    static let mutedText = Color.white.opacity(0.35)

    // Surfaces
    static let rowFill = Color.white.opacity(0.06)
    static let rowFillHover = Color.white.opacity(0.10)
    static let chipFill = Color.white.opacity(0.07)

    // Selection: a soft light fill plus a brighter ring, used for the
    // keyboard-focused row anywhere in the window.
    static let selectionFill = Color.white.opacity(0.16)
    static let selectionRing = Color.white.opacity(0.55)

    static let divider = Color.white.opacity(0.08)

    // The accent used for completion marks.
    static let accent = Color.white.opacity(0.9)

    // Metrics
    static let rowCorner: CGFloat = 9
    static let rowVPadding: CGFloat = 11
    static let rowHPadding: CGFloat = 13
    static let sectionGap: CGFloat = 18
}

extension View {
    /// Draws the keyboard-focus selection treatment when `focused` is true:
    /// a filled background and a bright rounded ring.
    @ViewBuilder
    func focusRing(_ focused: Bool, corner: CGFloat = Style.rowCorner) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(focused ? Style.selectionRing : Color.clear, lineWidth: 1.5)
        )
    }
}
