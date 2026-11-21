//
//  ResolvedText+Instant.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title at an instant, in its box at the static values. Its glyphs move along their lines by the tracking then and
// with their lines by the line height then, and each line is placed again by `align` on its width then. Its box is its
// text box then grown by its background's padding then. A glyph box is a character's or a hanging space's: from the pen
// where its glyphs begin, as wide as its advance, and down its line from the baseline less the line's ascent to the
// baseline plus its descent.
extension ResolvedText {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func box(at time: Double) -> Rectangle {
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
    func textBox(at time: Double) -> Rectangle {
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

    // The title's drawn extent at `time`, in its text box then: the text box grown to hold the glyph box then of every
    // character with glyphs of its own and of every space hanging at a line's end, each raised by its run's baseline
    // shift then.
    func extent(at time: Double) -> Rectangle {
        let box = textBox(at: time)
        let moves = glyphMoves(at: time)
        let glyphBoxes = lines.indices.flatMap { line in
            glyphBoxes(of: lines[line].clusters + lines[line].hanging, on: line, moves: moves, at: time)
        }

        return glyphBoxes.reduce(Rectangle(x: 0, y: 0, width: box.width, height: box.height)) { $0.union($1) }
    }

    // How far each glyph moves at `time`, by run and glyph: along its line by the tracking steps after the characters
    // before it on its line and its line's move by `align`, and down with its line. A space hanging at a line's end
    // moves with the line's last character, or with its line on a line with no character.
    func glyphMoves(at time: Double) -> [[Point]] {
        var moves = runs.map { run in Array(repeating: Point(x: 0, y: 0), count: run.glyphs.count) }
        let steps = trackingSteps(at: time)
        for (line, drop) in zip(lines, lineDrops(at: time)) {
            let added = addedWidth(of: line, steps: steps)
            let shift = align.offset(of: line.width + added, in: textBox.width)
                - align.offset(of: line.width, in: textBox.width)
            var before = 0.0
            var last = 0.0
            for cluster in line.clusters.map(\.glyphs) where cluster.count > 0 {
                for index in cluster.first..<(cluster.first + cluster.count) {
                    moves[cluster.run][index] = Point(x: before + shift, y: drop)
                }
                last = before
                before += steps[cluster.run]
            }
            for space in line.hanging.map(\.glyphs) {
                for index in space.first..<(space.first + space.count) {
                    moves[space.run][index] = Point(x: last + shift, y: drop)
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
        at time: Double
    ) -> [Rectangle] {
        let origin = textBox(at: time)
        let ascent = lines[line].ascent
        let descent = lines[line].descent

        return clusters.filter { $0.glyphs.count > 0 }.map { cluster in
            let run = runs[cluster.glyphs.run]
            let move = moves[cluster.glyphs.run][cluster.glyphs.first]
            let shift = run.baselineShift.sampled(at: time, as: .leaf(.length(.any))).number ?? 0

            return Rectangle(
                x: run.glyphs[cluster.glyphs.first].x + move.x - origin.x,
                y: lines[line].baseline + move.y - shift - ascent - origin.y,
                width: cluster.advance,
                height: ascent + descent
            )
        }
    }

    // How far each run's pieces move with the glyph moves `moves`: a piece's start with the run's first glyph, and its
    // end with the last glyph of the last character of the run's `source` on its line.
    func pieceMoves(of moves: [[Point]]) -> [PieceMove] {
        let still = PieceMove(start: Point(x: 0, y: 0), end: Point(x: 0, y: 0))
        var pieces = runs.map { _ in still }
        for line in lines {
            var ends: [Int: Point] = [:]
            for cluster in line.clusters.map(\.glyphs) where cluster.count > 0 {
                ends[runs[cluster.run].source] = moves[cluster.run][cluster.first + cluster.count - 1]
            }
            for run in Set(line.clusters.map(\.glyphs.run)) {
                guard let start = moves[run].first, let end = ends[runs[run].source] else { continue }

                pieces[run] = PieceMove(start: start, end: end)
            }
        }

        return pieces
    }

    // MARK: - Private
    // How far each line moves down at `time`: the first baseline stays, and each later one lies the line height then
    // below the one before it.
    private func lineDrops(at time: Double) -> [Double] {
        guard let first = lines.first else { return [] }
        guard let lineHeight = lineHeight.sampled(at: time, as: .leaf(.length(.any))).number else {
            return lines.map { _ in 0 }
        }

        return lines.enumerated().map { index, line in first.baseline + Double(index) * lineHeight - line.baseline }
    }

    // The background's padding at `time`, written vertical then horizontal.
    private func padding(at time: Double) -> Size {
        let structure = ValueStructure.leaf(.lengths(count: 2, domain: .nonNegative))
        guard let numbers = background?.padding.sampled(at: time, as: structure).numbers, numbers.count == 2 else {
            return Size(width: 0, height: 0)
        }

        return Size(width: numbers[1], height: numbers[0])
    }

    private func trackingSteps(at time: Double) -> [Double] {
        runs.map { run in run.tracking.sampled(at: time, as: .leaf(.length(.any))).number ?? 0 }
    }

    // The width the tracking at its steps adds to a line: a step after every character with glyphs of its own but the
    // line's last.
    private func addedWidth(
        of line: PlacedLine,
        steps: [Double]
    ) -> Double {
        line.clusters.filter { $0.glyphs.count > 0 }.dropLast().map { steps[$0.glyphs.run] }.reduce(0, +)
    }
}
