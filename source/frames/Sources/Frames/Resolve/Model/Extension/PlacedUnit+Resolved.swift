//
//  PlacedUnit+Resolved.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A unit as resolved, its box holding what it draws at its widest over the keyframes: grown on every side by half the
// widest stroke among its glyphs, then to hold its highlight parts at their largest padding and its underline parts at
// their largest `width` and `offset`. A first or last part, which reaches its piece's end, holds the padding there.
extension PlacedUnit {
    // MARK: - Property
    // MARK: - Initializer
    init(
        drawing unit: PlacedUnit,
        runs: [ResolvedGlyphRun]
    ) {
        let stroke = unit.glyphs.flatMap { Self.values(of: runs[$0.run].stroke["width"]) }.compactMap(\.first).max() ?? 0
        let parts = unit.parts.flatMap { part in
            let run = runs[part.run]
            let highlight = run.highlight.flatMap { highlight in
                highlight.rects.indices.contains(part.piece)
                    ? Self.drawn(part, of: highlight.rects[part.piece], padding: highlight.padding)
                    : nil
            }
            let underline = run.underline.flatMap { underline in
                underline.rects.indices.contains(part.piece)
                    ? Self.drawn(part, of: underline.rects[part.piece], underline: underline)
                    : nil
            }

            return [highlight, underline].compactMap { $0 }
        }

        self.init(
            glyphs: unit.glyphs,
            box: parts.reduce(unit.box.grown(by: stroke / 2)) { $0.union($1) },
            parts: unit.parts
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static func drawn(
        _ part: UnitPart,
        of piece: Rectangle,
        padding: TimedValue
    ) -> Rectangle {
        let paddings = values(of: padding)
        let vertical = paddings.map { $0.first ?? 0 }.max() ?? 0
        let horizontal = paddings.map { $0.last ?? 0 }.max() ?? 0
        let start = part.span.lowerBound == piece.x ? piece.x - horizontal : part.span.lowerBound
        let end = part.span.upperBound == piece.maxX ? piece.maxX + horizontal : part.span.upperBound

        return Rectangle(x: start, y: piece.y - vertical, width: end - start, height: piece.height + vertical * 2)
    }

    // An underline piece lies on the baseline, its band from `offset` to `offset + width` below it.
    private static func drawn(
        _ part: UnitPart,
        of piece: UnderlinePiece,
        underline: ResolvedUnderline
    ) -> Rectangle {
        let offsets = values(of: underline.offset).compactMap(\.first)
        let width = values(of: underline.width).compactMap(\.first).max() ?? 0
        let top = piece.y + (offsets.min() ?? 0)
        let bottom = piece.y + (offsets.max() ?? 0) + width

        return Rectangle(
            x: part.span.lowerBound,
            y: top,
            width: part.span.upperBound - part.span.lowerBound,
            height: bottom - top
        )
    }

    // The numbers a timed leaf takes at its keyframes.
    private static func values(of value: TimedValue?) -> [[Double]] {
        guard case let .track(keyframes)? = value else { return [] }

        return keyframes.compactMap { keyframe in
            switch keyframe.value {
            case let .number(number):
                [number]

            case let .numbers(numbers):
                numbers

            case .color, .area, .point:
                nil
            }
        }
    }
}
