//
//  DrawnStroke.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The part of an outline a stroke draws (FRAMES-11), as distances along the outline: from the smaller trim to the
// larger, each held to 0...1. Arrowheads sit on the ends of the stroke as drawn, so an open outline's stroke has an end
// at both, and a closed outline's only where its trim leaves part of it undrawn: drawn whole, it has no end and takes
// no arrowhead. A head is `4 × width` long, and heads that together are longer than the drawn stroke shrink to share
// its length. The line runs between the heads' bases.
package struct DrawnStroke: Equatable, Sendable {
    // MARK: - Property
    package let start: Double
    package let end: Double
    package let isWhole: Bool
    package let hasStartHead: Bool
    package let hasEndHead: Bool
    package let headLength: Double

    package var lineStart: Double { start + (hasStartHead ? headLength : 0) }
    package var lineEnd: Double { end - (hasEndHead ? headLength : 0) }

    // MARK: - Initializer
    // Nil where the stroke draws nothing: no width, or no part of the outline.
    package init?(
        stroke: PathStroke,
        trim: Trim,
        isClosed: Bool,
        length: Double
    ) {
        let low = min(max(min(trim.start, trim.end), 0), 1)
        let high = min(max(max(trim.start, trim.end), 0), 1)
        guard stroke.width > 0, high > low, length > 0 else { return nil }

        let isWhole = isClosed && low == 0 && high == 1
        let hasStartHead = !isWhole && stroke.start == .arrow
        let hasEndHead = !isWhole && stroke.end == .arrow
        let count = Double([hasStartHead, hasEndHead].filter { $0 }.count)

        self.start = low * length
        self.end = high * length
        self.isWhole = isWhole
        self.hasStartHead = hasStartHead
        self.hasEndHead = hasEndHead
        self.headLength = count > 0 ? min(4 * stroke.width, (high - low) * length / count) : 0
    }

    // MARK: - Public
    // MARK: - Private
}
