//
//  ResolvedText+Unit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title's units at an instant, in its text box then, whose top left is `textBox(at:)`'s origin. A unit's box and its
// glyph box are their boxes as resolved, their left edges moved as the leftmost left edge among the glyph boxes of the
// characters it holds moves and their right edges as the rightmost right edge does, and down with its line. A part
// moves its cuts with the characters whose left edges they lie at, the leftmost character of its stretch of its piece
// and the one right of its rightmost, and the leftmost and rightmost parts of a piece reach past its ends, so they hold
// its padding at any value.
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
        let glyphBoxes = glyphBoxes(ofCharacters: characters.clusters, on: characters.line, moves: moves, at: time)
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
        let line = units[index].characters.line
        let parts = units[index].parts

        return parts.indices.map { offset in
            let part = parts[offset]
            let earlier = parts[..<offset].filter { $0.run == part.run && $0.piece == part.piece }.count
            let cuts = cuts(of: part, on: line, units: units)
            guard let order = cuts.indices.filter({ cuts[$0].unit == index }).dropFirst(earlier).first else {
                return UnitPart(
                    run: part.run,
                    piece: part.piece,
                    span: (part.span.lowerBound - origin.x)...(part.span.upperBound - origin.x)
                )
            }

            let move = { (cut: Int) in self.move(of: cuts[cut].first, on: self.lines[line], moves: moves).x - origin.x }
            let start = order == 0 ? -Double.infinity : part.span.lowerBound + move(order)
            let end = order == cuts.count - 1 ? Double.infinity : part.span.upperBound + move(order + 1)

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
        let line = lines[unit.characters.line]
        let edges = heldOwners(of: unit).map { owner in
            let glyphs = line.clusters[owner].glyphs
            let x = runs[glyphs.run].glyphs[glyphs.first].x

            return (left: x, right: x + line.clusters[owner].advance, move: moves[glyphs.run][glyphs.first])
        }
        guard let first = edges.first else {
            return Rectangle(x: box.x - origin.x, y: box.y - origin.y, width: box.width, height: box.height)
        }

        let left = edges.map(\.left).reduce(first.left, min)
        let right = edges.map(\.right).reduce(first.right, max)
        let movedLeft = edges.map { $0.left + $0.move.x }.reduce(first.left + first.move.x, min)
        let movedRight = edges.map { $0.right + $0.move.x }.reduce(first.right + first.move.x, max)

        return Rectangle(
            x: box.x + movedLeft - left - origin.x,
            y: box.y + first.move.y - origin.y,
            width: box.width + (movedRight - right) - (movedLeft - left),
            height: box.height
        )
    }

    // The characters with glyphs a unit's characters but its spaces are drawn with, by their index on its line.
    private func heldOwners(of unit: PlacedUnit) -> [Int] {
        let scalars = Array(text.unicodeScalars)
        let line = lines[unit.characters.line]

        return unit.characters.clusters
            .filter { !scalars[line.clusters[$0].range].isSpace }
            .compactMap { line.owner(of: $0) }
    }

    // The cuts of the piece `part` is of on the line at `line`, from left to right: each stretch of the piece's
    // characters as placed that go with one of `units`, as that unit and the stretch's leftmost character, as resolve
    // cut them.
    private func cuts(
        of part: UnitPart,
        on line: Int,
        units: [PlacedUnit]
    ) -> [(unit: Int, first: Int)] {
        let pieces = lines[line].pieces(of: runs[part.run].source, sources: runs.map(\.source))
        guard pieces.indices.contains(part.piece) else { return [] }

        var unitAt: [Int: Int] = [:]
        for (unit, placed) in units.enumerated() where placed.characters.line == line {
            for cluster in placed.characters.clusters {
                unitAt[cluster] = unit
            }
        }

        return pieces[part.piece].reduce(into: []) { cuts, character in
            guard let unit = unitAt[character], cuts.last?.unit != unit else { return }

            cuts.append((unit, character))
        }
    }
}
