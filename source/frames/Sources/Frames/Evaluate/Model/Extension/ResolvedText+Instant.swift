//
//  ResolvedText+Instant.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title at an instant, in its box at the static values. With `lines` its glyphs move along their lines by the
// tracking then and with their lines by the line height then, and each line is placed again by `align` on its width
// then. Its box is its text box then grown by its background's padding then.
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

    // How far each glyph moves at `time`, by run and glyph: along its line by the tracking steps of the clusters before
    // it on its line and its line's move by `align`, and down with its line. A glyph of no cluster, a space hanging at
    // a line's end, stays.
    func glyphMoves(at time: SampleTime) -> [[Point]] {
        var moves = runs.map { run in Array(repeating: Point(x: 0, y: 0), count: run.glyphs.count) }
        guard let lines else { return moves }

        let steps = trackingSteps(at: time)
        for (line, drop) in zip(lines, lineDrops(at: time)) {
            let added = addedWidth(of: line, steps: steps)
            let shift = align.offset(of: line.width + added, in: textBox.width)
                - align.offset(of: line.width, in: textBox.width)
            var before = 0.0
            for cluster in line.clusters {
                for index in cluster.first..<(cluster.first + cluster.count) {
                    moves[cluster.run][index] = Point(x: before + shift, y: drop)
                }
                before += steps[cluster.run]
            }
        }

        return moves
    }

    // How far each run's pieces move with the glyph moves `moves`: a piece's start with the run's first glyph, and its
    // end with the last visible glyph of the run's `source` on its line.
    func pieceMoves(of moves: [[Point]]) -> [PieceMove] {
        let still = PieceMove(start: Point(x: 0, y: 0), end: Point(x: 0, y: 0))
        var pieces = runs.map { _ in still }
        guard let lines else { return pieces }

        for line in lines {
            var ends: [Int: Point] = [:]
            for cluster in line.clusters where cluster.count > 0 {
                ends[runs[cluster.run].source] = moves[cluster.run][cluster.first + cluster.count - 1]
            }
            for run in Set(line.clusters.map(\.run)) {
                guard let start = moves[run].first, let end = ends[runs[run].source] else { continue }

                pieces[run] = PieceMove(start: start, end: end)
            }
        }

        return pieces
    }

    // MARK: - Private
    // A title with a width keeps it, and one without is as wide as its widest line then, keeping the edge or the
    // centre `align` names. The top edge stays, and the box ends as far below the last line's baseline as it did.
    private func textBox(at time: SampleTime) -> Rectangle {
        guard let lines else { return textBox }

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

    // How far each line moves down at `time`: the first baseline stays, and each later one lies the line height then
    // below the one before it.
    private func lineDrops(at time: SampleTime) -> [Double] {
        guard let lines, let first = lines.first else { return [] }
        guard let lineHeight = lineHeight.sampled(at: time, as: .leaf(.length(.any))).number else {
            return lines.map { _ in 0 }
        }

        return lines.enumerated().map { index, line in first.baseline + Double(index) * lineHeight - line.baseline }
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

    // The width the tracking at its steps adds to a line: a step after every cluster but the last.
    private func addedWidth(
        of line: PlacedLine,
        steps: [Double]
    ) -> Double {
        line.clusters.dropLast().map { steps[$0.run] }.reduce(0, +)
    }
}
