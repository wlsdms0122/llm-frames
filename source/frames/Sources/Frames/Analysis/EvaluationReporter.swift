//
//  EvaluationReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Evaluates a resolved sequence at a time in [0, duration) and reports its display list as `evaluate` prints it,
// nested lists flattened, with the text of every title drawn then. A title's text is read from the resolved title at
// the time evaluation samples it at, not from its items. A title's first item names it and gives its text box's map
// to output pixels: its one item, or the background item under its units, which carries the title's transform without
// a unit's motion. A unit's `fills` item is the k-th unit's when it is the title's k-th `fills` item.
package struct EvaluationReporter: Sendable {
    // MARK: - Property
    private let evaluator = Evaluator()
    private let flattener = DisplayListFlattener()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func report(
        of sequence: ResolvedSequence,
        at time: Double
    ) throws -> EvaluationReport {
        try FrameSpan(end: sequence.format.duration, kind: "sequence").check(time, option: "--at")

        return report(of: evaluator.displayList(of: sequence, at: time), titles: sequence.titles(at: time), at: time)
    }

    // `titles` are the resolved titles the list's glyphs items are drawn from, by place.
    func report(
        of list: DisplayList,
        titles: [String: TitleSample] = [:],
        at time: Double
    ) -> EvaluationReport {
        var items: [EvaluationItem] = []
        var texts: [EvaluationText] = []
        var units: [String: Int] = [:]
        for item in flattener.items(of: list) {
            guard item.item == .glyphs, let origin = item.origin, let title = titles[origin.place] else {
                items.append(EvaluationItem(item))
                continue
            }

            if !texts.contains(where: { $0.place == origin.place }) {
                texts.append(text(of: title, origin: origin, transform: item.transform))
            }
            switch item.characters {
            case .title:
                items.append(EvaluationItem(item, characters: title.text.characters(at: title.time)))

            case .unit:
                let unit = units[origin.place, default: 0]
                units[origin.place] = unit + 1
                items.append(EvaluationItem(item, characters: title.text.characters(of: unit, at: title.time)))

            case .none:
                items.append(EvaluationItem(item))
            }
        }

        return EvaluationReport(time: time, size: list.size, items: items, texts: texts)
    }

    // MARK: - Private
    // The title's box is its text box grown by its background's padding, given in its text box.
    private func text(
        of title: TitleSample,
        origin: ItemOrigin,
        transform: AffineTransform
    ) -> EvaluationText {
        let text = title.text
        let textBox = text.textBox(at: title.time)
        let box = text.box(at: title.time)

        return EvaluationText(
            place: origin.place,
            id: origin.id,
            text: text.text,
            size: Size(width: textBox.width, height: textBox.height),
            box: Rectangle(x: box.x - textBox.x, y: box.y - textBox.y, width: box.width, height: box.height),
            transform: transform,
            lines: text.evaluationLines(at: title.time),
            words: text.evaluationWords
        )
    }
}
