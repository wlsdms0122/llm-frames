//
//  ResolvedText+Instant.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title with `lines` moves its glyphs along their lines by the tracking at each instant, and places each line again
// by `align` on its width then, inside the text box resolve sized at the static tracking.
extension ResolvedText {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // How far each glyph moves along its line at `time`, by run and glyph: the tracking steps of the clusters before it
    // on its line, and its line's move by `align`. A glyph of no cluster, a space hanging at a line's end, stays.
    func glyphMoves(at time: Double) -> [[Double]] {
        var moves = runs.map { run in Array(repeating: 0.0, count: run.glyphs.count) }
        guard let lines else { return moves }

        let steps = trackingSteps(at: time)
        let room = textWidth
        for line in lines {
            let added = addedWidth(of: line, steps: steps)
            let shift = align.offset(of: line.width + added, in: room) - align.offset(of: line.width, in: room)
            var before = 0.0
            for cluster in line.clusters {
                for index in cluster.first..<(cluster.first + cluster.count) {
                    moves[cluster.run][index] = before + shift
                }
                before += steps[cluster.run]
            }
        }

        return moves
    }

    // The text box at `time`, in the text's box with its background's padding. A title with a width keeps it, and
    // one without is as wide as its widest line then, keeping the edge or the centre `align` names.
    func textBox(at time: Double) -> Rectangle {
        let padding = background?.padding ?? Size(width: 0, height: 0)
        let room = textWidth
        guard let lines else {
            return Rectangle(x: padding.width, y: padding.height, width: room, height: size.height - padding.height * 2)
        }

        let steps = trackingSteps(at: time)
        let width = self.width.map { _ in room }
            ?? lines.map { $0.width + addedWidth(of: $0, steps: steps) }.reduce(0, max)

        return Rectangle(
            x: padding.width + align.offset(of: width, in: room),
            y: padding.height,
            width: width,
            height: size.height - padding.height * 2
        )
    }

    // MARK: - Private
    private var textWidth: Double {
        size.width - (background?.padding.width ?? 0) * 2
    }

    private func trackingSteps(at time: Double) -> [Double] {
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
