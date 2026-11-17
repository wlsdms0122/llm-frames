//
//  EvaluationReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Evaluates a resolved document at a time and reports its display list as `evaluate` prints it, nested lists
// flattened. A sequence takes a time in [0, duration), and an image or layout any time, giving its one list.
package struct EvaluationReporter: Sendable {
    // MARK: - Property
    private let evaluator = Evaluator()
    private let flattener = DisplayListFlattener()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func report(
        of document: ResolvedDocument,
        at time: Double
    ) throws -> EvaluationReport {
        if case let .sequence(sequence) = document {
            try FrameSpan(end: sequence.format.duration, kind: "sequence").check(time, option: "--at")
        }

        return report(of: evaluator.displayList(of: document, at: time), at: time)
    }

    func report(
        of list: DisplayList,
        at time: Double
    ) -> EvaluationReport {
        EvaluationReport(time: time, size: list.size, items: flattener.items(of: list).map(EvaluationItem.init))
    }

    // MARK: - Private
}
