//
//  ResolvedText+Placement.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Where a title's text lies at an instant, as `evaluate` reports it, in its text box then and read from the resolved
// title alone. A character lies in its glyph box then, the box of its first glyph's pen and its advance on its line,
// moved as its glyphs move then and raised by its run's baseline shift then, and sits on its line's baseline then less
// that shift. A character with no glyph of its own lies where its group's first character does, and one with no
// character with glyphs before it on its line where the line starts then. A line lies where its baseline is then, with
// no shift. A space hanging at a line's end is no character.
extension ResolvedText {
    // MARK: - Property
    var evaluationWords: [EvaluationWord] {
        words.map { EvaluationWord(text: text.text(over: $0), range: $0) }
    }

    // MARK: - Initializer
    // MARK: - Public
    // Every character of the title, in reading order.
    func characters(at time: Double) -> [EvaluationCharacter] {
        let moves = glyphMoves(at: time)

        return lines.indices.flatMap { line in
            characters(lines[line].clusters.indices, on: line, moves: moves, at: time)
        }
    }

    // The characters of the unit at `index`: those it holds and the spaces that go with it, in reading order.
    func characters(
        of index: Int,
        at time: Double
    ) -> [EvaluationCharacter] {
        guard let units, units.indices.contains(index) else { return [] }

        let stretch = units[index].characters

        return characters(
            stretch.first..<(stretch.first + stretch.count),
            on: stretch.line,
            moves: glyphMoves(at: time),
            at: time
        )
    }

    func evaluationLines(at time: Double) -> [EvaluationLine] {
        let top = textBox(at: time).y

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
        at time: Double
    ) -> [EvaluationCharacter] {
        let rects = glyphBoxes(ofCharacters: indices, on: line, moves: moves, at: time)

        return zip(indices, rects).map { index, rect in
            let cluster = lines[line].clusters[index]

            return EvaluationCharacter(
                text: text.text(over: cluster.range),
                range: cluster.range,
                rect: rect,
                baseline: rect.y + lines[line].ascent
            )
        }
    }
}
