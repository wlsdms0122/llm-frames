//
//  ResolvedText+Unit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title's units at an instant, in its box then, whose top left is `box(at:)`'s origin. A unit's box and its glyph box
// are their boxes as resolved, moved with its first glyph and widened by how far its last glyph moves beyond its first.
// A part is cut where the next unit's first glyph is then, and the first and last parts of a piece reach past its ends,
// so they hold its padding at any value.
extension ResolvedText {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func unitBox(
        of index: Int,
        at time: SampleTime
    ) -> Rectangle {
        guard let unit = units?[index] else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }

        return moved(unit.box, of: unit, at: time)
    }

    func glyphBox(
        of index: Int,
        at time: SampleTime
    ) -> Rectangle {
        guard let unit = units?[index] else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }

        return moved(unit.glyphBox, of: unit, at: time)
    }

    func parts(
        of index: Int,
        at time: SampleTime
    ) -> [UnitPart] {
        guard let units, units.indices.contains(index) else { return [] }

        let origin = box(at: time)
        let moves = glyphMoves(at: time)

        return units[index].parts.map { part in
            let sharing = units.indices
                .flatMap { unit in
                    units[unit].parts
                        .filter { $0.run == part.run && $0.piece == part.piece }
                        .map { (unit: unit, start: $0.span.lowerBound) }
                }
                .sorted { $0.start < $1.start }
            let order = sharing.firstIndex { $0.unit == index } ?? 0
            let start = order == 0
                ? -Double.infinity
                : part.span.lowerBound + firstMove(of: units[index], moves: moves).x - origin.x
            let end = order == sharing.count - 1
                ? Double.infinity
                : part.span.upperBound + firstMove(of: units[sharing[order + 1].unit], moves: moves).x - origin.x

            // A tracking that tightens fast may carry the next unit's start past this one's.
            return UnitPart(run: part.run, piece: part.piece, span: start...max(start, end))
        }
    }

    // MARK: - Private
    private func moved(
        _ box: Rectangle,
        of unit: PlacedUnit,
        at time: SampleTime
    ) -> Rectangle {
        let origin = self.box(at: time)
        let moves = glyphMoves(at: time)
        let start = firstMove(of: unit, moves: moves)
        let end = unit.glyphs.last.map { moves[$0.run][$0.first + $0.count - 1] } ?? start

        return Rectangle(
            x: box.x + start.x - origin.x,
            y: box.y + start.y - origin.y,
            width: box.width + end.x - start.x,
            height: box.height
        )
    }

    private func firstMove(
        of unit: PlacedUnit,
        moves: [[Point]]
    ) -> Point {
        unit.glyphs.first.map { moves[$0.run][$0.first] } ?? Point(x: 0, y: 0)
    }
}
