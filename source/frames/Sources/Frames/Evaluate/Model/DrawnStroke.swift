//
//  DrawnStroke.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The part of an outline a stroke draws, as fractions of the outline's length. Arrowheads sit on the ends of the stroke
// as drawn, so a closed outline drawn whole takes none. Heads that together are longer than the drawn stroke shrink to
// share its length, and the line runs between their bases. Where a head lies is `PathOutline.arrowheads(of:)`'s to say.
package struct DrawnStroke: Equatable, Sendable {
    // MARK: - Property
    package let isDrawn: Bool
    package let isWhole: Bool
    package let hasStartHead: Bool
    package let hasEndHead: Bool
    private let low: Double
    private let high: Double
    private let width: Double

    package var hasArrowhead: Bool { hasStartHead || hasEndHead }

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

        self.isDrawn = isDrawn
        self.isWhole = isWhole
        self.hasStartHead = isDrawn && !isWhole && stroke.start == .arrow
        self.hasEndHead = isDrawn && !isWhole && stroke.end == .arrow
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

    // The length of each head along an outline `length` long, after shrinking.
    package func headLength(along length: Double) -> Double {
        let count = Double([hasStartHead, hasEndHead].filter { $0 }.count)
        guard count > 0 else { return 0 }

        return min(4 * width, (high - low) * length / count)
    }

    // Where the line between the heads' bases starts and ends along an outline `length` long.
    package func lineStart(along length: Double) -> Double {
        start(along: length) + (hasStartHead ? headLength(along: length) : 0)
    }

    package func lineEnd(along length: Double) -> Double {
        end(along: length) - (hasEndHead ? headLength(along: length) : 0)
    }

    // MARK: - Private
}
