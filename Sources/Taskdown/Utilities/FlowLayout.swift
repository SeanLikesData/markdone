import SwiftUI

/// A simple left-to-right wrapping layout, used for the habit chips row so
/// chips flow onto a second line when they do not fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = (rows[rows.count - 1].isEmpty ? 0 : spacing) + size.width
            if currentRowWidth + needed > maxWidth && !rows[rows.count - 1].isEmpty {
                totalHeight += currentRowHeight + spacing
                rows.append([])
                currentRowWidth = 0
                currentRowHeight = 0
            }
            rows[rows.count - 1].append(size)
            currentRowWidth += (rows[rows.count - 1].count == 1 ? 0 : spacing) + size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth == .infinity ? currentRowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0
        var isFirstInRow = true

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = (isFirstInRow ? 0 : spacing) + size.width
            if x - bounds.minX + needed > maxWidth && !isFirstInRow {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
                isFirstInRow = true
            }
            if !isFirstInRow { x += spacing }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width
            currentRowHeight = max(currentRowHeight, size.height)
            isFirstInRow = false
        }
    }
}
