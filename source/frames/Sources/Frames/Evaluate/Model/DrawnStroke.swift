//
//  DrawnStroke.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The part of an outline a stroke draws, as fractions of the outline's length. Heads sit on the ends of the stroke as
// drawn, so a closed outline drawn whole takes none. Each head is drawn in a unit, the stroke's width times its scale,
// and heads that together are longer than the drawn stroke shrink by one factor to share its length, keeping their
// shapes. The line runs between the points its heads stop it at. Where a head lies is `PathOutline.arrowheads(of:)`'s
// to say.
package struct DrawnStroke: Equatable, Sendable {
    // MARK: - Property
    package let isDrawn: Bool
    package let isWhole: Bool
    // The ends the stroke draws, `none` where it draws no head there.
    package let startHead: StrokeEnd
    package let endHead: StrokeEnd
    private let low: Double
    private let high: Double
    private let width: Double

    package var hasArrowhead: Bool { startHead.shape != .none || endHead.shape != .none }

    // MARK: - Initializer
    package init(
        stroke: PathStroke,
        trim: Trim,
        isClosed: Bool
    ) {
        let low = min(max(min(trim.start, trim.end), 0), 1)
        let high = min(max(max(trim.start, trim.end), 0), 1)
        let isDrawn = stroke.width > 0 && high > low
        let isWhole = isClosed && low == 0 && high == 1
        let hasEnds = isDrawn && !isWhole
        let head = { (end: StrokeEnd) in hasEnds && end.unit(width: stroke.width) > 0 ? end : StrokeEnd.none }

        self.isDrawn = isDrawn
        self.isWhole = isWhole
        self.startHead = head(stroke.start)
        self.endHead = head(stroke.end)
        self.low = low
        self.high = high
        self.width = stroke.width
    }

    // MARK: - Public
    // Where the drawn stroke starts and ends along an outline `length` long.
    package func start(along length: Double) -> Double {
        low * length
    }

    package func end(along length: Double) -> Double {
        high * length
    }

    // The unit a head is drawn in along an outline `length` long, after shrinking, 0 where it draws none.
    package func unit(
        of head: StrokeEnd,
        along length: Double
    ) -> Double {
        head.unit(width: width) * shrink(along: length)
    }

    // Where the line between the heads starts and ends along an outline `length` long.
    package func lineStart(along length: Double) -> Double {
        start(along: length) + startHead.shape.inset * unit(of: startHead, along: length)
    }

    package func lineEnd(along length: Double) -> Double {
        end(along: length) - endHead.shape.inset * unit(of: endHead, along: length)
    }

    // MARK: - Private
    // The factor the heads shrink by along an outline `length` long: 1, or less where together they are longer than
    // the drawn stroke.
    private func shrink(along length: Double) -> Double {
        let total = [startHead, endHead].map { $0.shape.length * $0.unit(width: width) }.reduce(0, +)
        guard total > 0 else { return 1 }

        return min(1, (high - low) * length / total)
    }
}
