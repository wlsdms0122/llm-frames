//
//  PlacedUnit+Resolved.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A unit as resolved, its box holding what it draws at its widest over the keyframes: its glyph box grown on every side
// by half the widest stroke among the glyphs it draws, then to hold its highlight parts at their largest padding and
// its underline parts at their largest `width` and `offset`. A first or last part, which reaches its piece's end, holds
// the padding there. A padding's first value is on the block axis and its second on the inline axis, which
// `writingMode` turns, as it turns an underline's band toward line-under.
extension PlacedUnit {
    // MARK: - Property
    // MARK: - Initializer
    init(
        drawing unit: PlacedUnit,
        lines: [PlacedLine],
        runs: [ResolvedGlyphRun],
        writingMode: WritingMode
    ) {
        let stroke = unit.glyphs.flatMap { Self.values(of: runs[$0.run].stroke["width"]) }.compactMap(\.first).max() ?? 0
        let parts = unit.parts.flatMap { part in
            let run = runs[part.run]
            let highlight = run.highlight.map { highlight in
                Self.drawn(part, of: highlight.rects[part.piece], padding: highlight.padding, writingMode: writingMode)
            }
            let underline = run.underline.map { underline in
                Self.drawn(part, of: underline.rects[part.piece], underline: underline, writingMode: writingMode)
            }

            return [highlight, underline].compactMap { $0 }
        }

        self.init(
            characters: unit.characters,
            hangingLines: unit.hangingLines,
            lines: lines,
            glyphCounts: runs.map(\.glyphs.count),
            glyphBox: unit.glyphBox,
            box: parts.reduce(unit.glyphBox.grown(by: stroke / 2)) { $0.union($1) },
            parts: unit.parts
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static func drawn(
        _ part: UnitPart,
        of piece: Rectangle,
        padding: TimedValue,
        writingMode: WritingMode
    ) -> Rectangle {
        let paddings = values(of: padding)
        let block = paddings.map { $0.first ?? 0 }.max() ?? 0
        let inline = paddings.map { $0.last ?? 0 }.max() ?? 0
        let piece = writingMode.turned(piece)
        let start = part.span.lowerBound == piece.x ? piece.x - inline : part.span.lowerBound
        let end = part.span.upperBound == piece.maxX ? piece.maxX + inline : part.span.upperBound

        return writingMode.turned(Rectangle(
            x: start,
            y: piece.y - block,
            width: end - start,
            height: piece.height + block * 2
        ))
    }

    // An underline piece lies on its run's alphabetic baseline, its band from `offset` to `offset + width` toward
    // line-under from it.
    private static func drawn(
        _ part: UnitPart,
        of piece: UnderlinePiece,
        underline: ResolvedUnderline,
        writingMode: WritingMode
    ) -> Rectangle {
        let offsets = values(of: underline.offset).compactMap(\.first)
        let width = values(of: underline.width).compactMap(\.first).max() ?? 0
        let baseline = writingMode.turned(Point(x: piece.x, y: piece.y)).y
        let top = writingMode.block(offsets.min() ?? 0, under: baseline)
        let bottom = writingMode.block(width, under: writingMode.block(offsets.max() ?? 0, under: baseline))

        return writingMode.turned(Rectangle(
            x: part.span.lowerBound,
            y: min(top, bottom),
            width: part.span.upperBound - part.span.lowerBound,
            height: abs(bottom - top)
        ))
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
