//
//  ResolvedText+Instant.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title at an instant, in its box at the static values. Its glyphs move along their lines by the tracking then, the
// tracking lying between neighbours as they are placed, and with their lines by the line height then, and each line is
// placed again by `align` on its width then. Its box is its text box then grown by its background's padding then. A
// glyph box is a character's or a hanging space's: from the pen where its glyphs begin, as wide as its advance, and
// down its line from the baseline less the line's ascent to the baseline plus its descent. A character with no glyph of
// its own has its group's first character's glyph box, and one with no character with glyphs before it on its line a
// box as wide as nothing where the line starts.
extension ResolvedText {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func box(at time: SampleTime) -> Rectangle {
        let padding = padding(at: time)
        let box = textBox(at: time)

        return Rectangle(
            x: box.x - padding.width,
            y: box.y - padding.height,
            width: box.width + padding.width * 2,
            height: box.height + padding.height * 2
        )
    }

    // The title's text box at `time`, in its box at the static values. A title with a width keeps it, and one without
    // is as wide as its widest line then, keeping the edge or the centre `align` names. The top edge stays, and the box
    // ends as far below the last line's baseline as it did.
    func textBox(at time: SampleTime) -> Rectangle {
        let steps = trackingSteps(at: time)
        let widest = lines.map { $0.width + addedWidth(of: $0, steps: steps) }.reduce(0, max)
        let width = self.width == nil ? widest : textBox.width

        return Rectangle(
            x: textBox.x + align.offset(of: width, in: textBox.width),
            y: textBox.y,
            width: width,
            height: textBox.height + (lineDrops(at: time).last ?? 0)
        )
    }

    // Where the title's text box lies in its box at `time`: the map from the text box's coordinates, its top left at
    // the origin, to the box's, its top left at the origin. A title's items and its masks lie in its text box, so each
    // takes this map into its box.
    func textBoxInBox(at time: SampleTime) -> AffineTransform {
        let box = box(at: time)
        let textBox = textBox(at: time)

        return AffineTransform(translation: Point(x: textBox.x - box.x, y: textBox.y - box.y))
    }

    // The title's box at `time` in its text box's coordinates, its top left at the origin: the box placed by the inverse
    // of `textBoxInBox(at:)`.
    func boxInTextBox(at time: SampleTime) -> Rectangle {
        let box = box(at: time)
        let textBoxInBox = textBoxInBox(at: time)

        return Rectangle(x: -textBoxInBox.tx, y: -textBoxInBox.ty, width: box.width, height: box.height)
    }

    // The title's drawn extent at `time`, in its text box then: the text box grown to hold the glyph box then of every
    // character and of every space hanging at a line's end, each raised by its run's baseline shift then.
    func extent(at time: SampleTime) -> Rectangle {
        let box = textBox(at: time)
        let moves = glyphMoves(at: time)
        let glyphBoxes = lines.indices.flatMap { line in
            glyphBoxes(ofCharacters: lines[line].clusters.indices, on: line, moves: moves, at: time)
                + glyphBoxes(of: lines[line].hanging, on: line, moves: moves, at: time)
        }

        return glyphBoxes.reduce(Rectangle(x: 0, y: 0, width: box.width, height: box.height)) { $0.union($1) }
    }

    // How far each glyph moves at `time`, by run and glyph: along its line by the tracking steps between the
    // neighbouring characters left of it as placed and its line's move by `align`, and down with its line. A space
    // hanging at a line's end moves with the outermost character on its side, or with its line on a line with no
    // character.
    func glyphMoves(at time: SampleTime) -> [[Point]] {
        var moves = runs.map { run in Array(repeating: Point(x: 0, y: 0), count: run.glyphs.count) }
        let steps = trackingSteps(at: time)
        for (line, drop) in zip(lines, lineDrops(at: time)) {
            let placed = line.clusters + line.hanging
            let along = trackingMoves(of: line, steps: steps)
            let shift = align.offset(of: line.width + along.added, in: textBox.width)
                - align.offset(of: line.width, in: textBox.width)
            for (index, move) in along.moves {
                let glyphs = placed[index].glyphs
                for glyph in glyphs.glyphs {
                    moves[glyphs.run][glyph] = Point(x: move + shift, y: drop)
                }
            }
        }

        return moves
    }

    // The glyph box at `time` of each of `clusters` on the line at `line` with glyphs of its own, moved by `moves` and
    // raised by its run's baseline shift then, in the text box then.
    func glyphBoxes(
        of clusters: [PlacedCluster],
        on line: Int,
        moves: [[Point]],
        at time: SampleTime
    ) -> [Rectangle] {
        let origin = textBox(at: time)

        return clusters.filter { $0.glyphs.count > 0 }.map { cluster in
            glyphBox(of: cluster, on: line, origin: origin, moves: moves, at: time)
        }
    }

    // The glyph box at `time` of each character at `indices` on the line at `line`, in the text box then. A character
    // with no glyph of its own has the box of its group's first character, and one with none before it a box as wide as
    // nothing where the line starts then, on its line's baseline then raised by its run's baseline shift then.
    func glyphBoxes(
        ofCharacters indices: Range<Int>,
        on line: Int,
        moves: [[Point]],
        at time: SampleTime
    ) -> [Rectangle] {
        let origin = textBox(at: time)
        let clusters = lines[line].clusters

        return indices.map { index in
            guard let owner = lines[line].owner(of: index) else {
                return lineStart(of: clusters[index], on: line, origin: origin, at: time)
            }

            return glyphBox(of: clusters[owner], on: line, origin: origin, moves: moves, at: time)
        }
    }

    // How far each piece of each run moves with the glyph moves `moves`, by run and piece: its start with its leftmost
    // character and its end with its rightmost, as they are placed. A run holds the pieces of its text run on its line,
    // in the order `PlacedLine.pieces(of:sources:)` gives them.
    func pieceMoves(of moves: [[Point]]) -> [[PieceMove]] {
        var pieces = runs.map { _ in [PieceMove]() }
        let sources = runs.map(\.source)
        for line in lines {
            for run in Set(line.clusters.map(\.glyphs.run)) {
                pieces[run] = line.pieces(of: runs[run].source, sources: sources).compactMap { characters in
                    guard let first = characters.first, let last = characters.last else { return nil }

                    return PieceMove(
                        start: move(of: first, on: line, moves: moves),
                        end: move(of: last, on: line, moves: moves)
                    )
                }
            }
        }

        return pieces
    }

    // How far the glyphs of the character at `index` on `line` move with the glyph moves `moves`: its group's first
    // character's, and not at all on a line with no glyph.
    func move(
        of index: Int,
        on line: PlacedLine,
        moves: [[Point]]
    ) -> Point {
        line.owner(of: index).map { owner in
            let glyphs = line.clusters[owner].glyphs

            return moves[glyphs.run][glyphs.first]
        } ?? Point(x: 0, y: 0)
    }

    // How far each line moves down at `time`: the first baseline stays, and each later one lies the line height then
    // below the one before it.
    func lineDrops(at time: SampleTime) -> [Double] {
        guard let first = lines.first else { return [] }
        guard let lineHeight = lineHeight.sampled(at: time, as: .leaf(.length(.any))).number else {
            return lines.map { _ in 0 }
        }

        return lines.enumerated().map { index, line in first.baseline + Double(index) * lineHeight - line.baseline }
    }

    // MARK: - Private
    private func glyphBox(
        of cluster: PlacedCluster,
        on line: Int,
        origin: Rectangle,
        moves: [[Point]],
        at time: SampleTime
    ) -> Rectangle {
        let run = runs[cluster.glyphs.run]
        let move = moves[cluster.glyphs.run][cluster.glyphs.first]
        let shift = run.baselineShift.sampled(at: time, as: .leaf(.length(.any))).number ?? 0

        return Rectangle(
            x: run.glyphs[cluster.glyphs.first].x + move.x - origin.x,
            y: lines[line].baseline + move.y - shift - lines[line].ascent - origin.y,
            width: cluster.advance,
            height: lines[line].ascent + lines[line].descent
        )
    }

    // The box as wide as nothing of `cluster`, which has no glyph, where the line at `line` starts at `time`: at the
    // line's place by `align` on its width then.
    private func lineStart(
        of cluster: PlacedCluster,
        on line: Int,
        origin: Rectangle,
        at time: SampleTime
    ) -> Rectangle {
        let placed = lines[line]
        let width = placed.width + addedWidth(of: placed, steps: trackingSteps(at: time))
        let drop = lineDrops(at: time)[line]
        let shift = runs[cluster.glyphs.run].baselineShift.sampled(at: time, as: .leaf(.length(.any))).number ?? 0

        return Rectangle(
            x: textBox.x + align.offset(of: width, in: textBox.width) - origin.x,
            y: placed.baseline + drop - shift - placed.ascent - origin.y,
            width: 0,
            height: placed.ascent + placed.descent
        )
    }

    // The background's padding at `time`, written vertical then horizontal.
    private func padding(at time: SampleTime) -> Size {
        let structure = ValueStructure.leaf(.lengths(count: 2, domain: .nonNegative))
        guard let numbers = background?.padding.sampled(at: time, as: structure).numbers, numbers.count == 2 else {
            return Size(width: 0, height: 0)
        }

        return Size(width: numbers[1], height: numbers[0])
    }

    private func trackingSteps(at time: SampleTime) -> [Double] {
        runs.map { run in run.tracking.sampled(at: time, as: .leaf(.length(.any))).number ?? 0 }
    }

    // The width the tracking at its steps adds to a line: a step between every two neighbouring characters with glyphs
    // of their own as placed.
    private func addedWidth(
        of line: PlacedLine,
        steps: [Double]
    ) -> Double {
        trackingMoves(of: line, steps: steps).added
    }

    // How far each of a line's clusters and hanging spaces with glyphs of its own moves along it by the tracking steps
    // `steps`, by its index among them: the steps between the neighbours left of it as placed, each the step of the run
    // of whichever of two neighbours comes first in the text. `added` is the width they add to the line.
    private func trackingMoves(
        of line: PlacedLine,
        steps: [Double]
    ) -> (moves: [(index: Int, move: Double)], added: Double) {
        let placed = line.clusters + line.hanging
        var added = 0.0
        let moves = line.placedOwners.map { owner in
            added += owner.tracking.map { steps[placed[$0].glyphs.run] } ?? 0

            return (index: owner.index, move: added)
        }

        return (moves, added)
    }
}
