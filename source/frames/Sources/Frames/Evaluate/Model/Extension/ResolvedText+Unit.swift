//
//  ResolvedText+Unit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title's units at an instant, in its text box then, whose top left is `textBox(at:)`'s origin. A unit's box and its
// glyph box are their boxes as resolved, moved with the first glyph of the characters it holds and widened by how far
// their last glyph moves beyond it. A part is cut where the next unit's first held glyph is then, and the first and last
// parts of a piece reach past its ends, so they hold its padding at any value.
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

    // The unit's drawn extent at `time`: the smallest box that holds the glyph boxes then of the characters that go with
    // it and of the hanging spaces it draws, each raised by its run's baseline shift then.
    func extent(
        of index: Int,
        at time: SampleTime
    ) -> Rectangle {
        guard let unit = units?[index] else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }

        let moves = glyphMoves(at: time)
        let characters = unit.characters
        let stretch = characters.first..<(characters.first + characters.count)
        let glyphBoxes = glyphBoxes(ofCharacters: stretch, on: characters.line, moves: moves, at: time)
            + unit.hangingLines.flatMap { line in glyphBoxes(of: lines[line].hanging, on: line, moves: moves, at: time) }
        guard let first = glyphBoxes.first else { return glyphBox(of: index, at: time) }

        return glyphBoxes.dropFirst().reduce(first) { $0.union($1) }
    }

    func parts(
        of index: Int,
        at time: SampleTime
    ) -> [UnitPart] {
        guard let units, units.indices.contains(index) else { return [] }

        let origin = textBox(at: time)
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
        let origin = textBox(at: time)
        let moves = glyphMoves(at: time)
        let held = heldGlyphs(of: unit)
        let start = firstMove(of: unit, moves: moves)
        let end = held.map { moves[$0.last.run][$0.last.index] } ?? start

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
        heldGlyphs(of: unit).map { moves[$0.first.run][$0.first.index] } ?? Point(x: 0, y: 0)
    }

    // The first and the last glyph of the characters a unit holds, its stretch's characters but its spaces, by run and
    // index. A character with no glyph of its own takes its group's, which its group's first character holds.
    private func heldGlyphs(of unit: PlacedUnit) -> (first: (run: Int, index: Int), last: (run: Int, index: Int))? {
        let scalars = Array(text.unicodeScalars)
        let clusters = lines[unit.characters.line].clusters
        let stretch = unit.characters.first..<(unit.characters.first + unit.characters.count)
        let owners = stretch
            .filter { !scalars[clusters[$0].range].isSpace }
            .compactMap { index in clusters[...index].last { $0.glyphs.count > 0 }?.glyphs }
        guard let first = owners.first, let last = owners.last else { return nil }

        return ((first.run, first.first), (last.run, last.first + last.count - 1))
    }
}
