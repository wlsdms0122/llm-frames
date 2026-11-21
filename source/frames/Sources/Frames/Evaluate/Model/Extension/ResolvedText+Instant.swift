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
// baseline plus its descent. A character with no glyph of its own has its group's first character's glyph box, and one
// with no character with glyphs before it on its line a box as wide as nothing where the line starts.
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

    // How far each glyph moves at `time`, by run and glyph: along its line by the tracking steps after the characters
    // before it on its line and its line's move by `align`, and down with its line. A space hanging at a line's end
    // moves with the line's last character, or with its line on a line with no character.
    func glyphMoves(at time: SampleTime) -> [[Point]] {
        var moves = runs.map { run in Array(repeating: Point(x: 0, y: 0), count: run.glyphs.count) }
        let steps = trackingSteps(at: time)
        for (line, drop) in zip(lines, lineDrops(at: time)) {
            let added = addedWidth(of: line, steps: steps)
            let shift = align.offset(of: line.width + added, in: textBox.width)
                - align.offset(of: line.width, in: textBox.width)
            var before = 0.0
            var last = 0.0
            for cluster in line.clusters.map(\.glyphs) where cluster.count > 0 {
                for index in cluster.glyphs {
                    moves[cluster.run][index] = Point(x: before + shift, y: drop)
                }
                last = before
                before += steps[cluster.run]
            }
            for space in line.hanging.map(\.glyphs) {
                for index in space.glyphs {
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
        at time: SampleTime
    ) -> [Rectangle] {
        let origin = textBox(at: time)

        return clusters.filter { $0.glyphs.count > 0 }.map { cluster in
            glyphBox(of: cluster, on: line, origin: origin, moves: moves, at: time)
        }
    }

    // The glyph box at `time` of each character at `indices` on the line at `line`, in the text box then. A character
    // with no glyph of its own has the box of the nearest character before it on its line with glyphs, its group's first
    // character, and one with none before it a box as wide as nothing where the line starts then, on its line's baseline
    // then raised by its run's baseline shift then.
    func glyphBoxes(
        ofCharacters indices: Range<Int>,
        on line: Int,
        moves: [[Point]],
        at time: SampleTime
    ) -> [Rectangle] {
        let origin = textBox(at: time)
        let clusters = lines[line].clusters

        return indices.map { index in
            guard let owner = clusters[...index].last(where: { $0.glyphs.count > 0 }) else {
                return lineStart(of: clusters[index], on: line, origin: origin, at: time)
            }

            return glyphBox(of: owner, on: line, origin: origin, moves: moves, at: time)
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

    // The width the tracking at its steps adds to a line: a step after every character with glyphs of its own but the
    // line's last.
    private func addedWidth(
        of line: PlacedLine,
        steps: [Double]
    ) -> Double {
        line.clusters.filter { $0.glyphs.count > 0 }.dropLast().map { steps[$0.glyphs.run] }.reduce(0, +)
    }
}
