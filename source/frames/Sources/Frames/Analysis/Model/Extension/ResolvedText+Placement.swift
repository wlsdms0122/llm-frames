//
//  ResolvedText+Placement.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Where a title's text lies at an instant, as `evaluate` reports it, in its text box then and read from the resolved
// title alone. A character lies in its glyph box then, the box of its first glyph's pen and its advance on its line,
// moved as its glyphs move then and raised by its run's baseline shift then, and sits on its line's baseline then less
// that shift, at the embedding level its cluster was resolved at. A character with no glyph of its own lies where the
// character it is drawn with does, and on a line with no glyph where the line starts then. A line lies where its
// baseline is then, with no shift. A space hanging at a line's end is no character. A baseline is a coordinate on the
// block axis, y in a horizontal writing mode and x in a vertical one.
extension ResolvedText {
    // MARK: - Property
    var evaluationWords: [EvaluationWord] {
        words.map { EvaluationWord(text: text.text(over: $0), range: $0) }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Every character of the title, in reading order.
    func characters(at time: SampleTime) -> [EvaluationCharacter] {
        let moves = glyphMoves(at: time)

        return lines.indices.flatMap { line in
            characters(lines[line].clusters.indices, on: line, moves: moves, at: time)
        }
    }

    // The characters of the unit at `index`: those it holds and the spaces that go with it, in reading order. `origin`
    // names the item that draws the unit, and the title it is drawn from.
    func characters(
        of index: Int,
        at time: SampleTime,
        drawnBy origin: ItemOrigin
    ) throws -> [EvaluationCharacter] {
        guard let units, units.indices.contains(index) else {
            throw AnalysisError.unknownUnit(place: origin.place, kind: origin.kind, unit: index, units: units?.count)
        }

        let stretch = units[index].characters

        return characters(
            stretch.clusters,
            on: stretch.line,
            moves: glyphMoves(at: time),
            at: time
        )
    }

    func evaluationLines(at time: SampleTime) -> [EvaluationLine] {
        let top = writingMode.turned(textBox(at: time)).y

        return zip(lines, lineDrops(at: time)).map { line, drop in
            EvaluationLine(
                text: text.text(over: line.range),
                range: line.range,
                baseline: line.baseline + drop - top,
                ascent: line.ascent,
                descent: line.descent
            )
        }
    }

    // MARK: - Private
    private func characters(
        _ indices: Range<Int>,
        on line: Int,
        moves: [[Point]],
        at time: SampleTime
    ) -> [EvaluationCharacter] {
        let rects = glyphBoxes(ofCharacters: indices, on: line, moves: moves, at: time)

        let placed = lines[line]
        let baselineInset = -writingMode.blockStart(around: 0, over: placed.ascent, under: placed.descent)

        return zip(indices, rects).map { index, rect in
            let cluster = placed.clusters[index]

            return EvaluationCharacter(
                text: text.text(over: cluster.range),
                range: cluster.range,
                level: cluster.level,
                rect: rect,
                baseline: writingMode.turned(rect).y + baselineInset
            )
        }
    }
}
