//
//  EvaluationReporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Evaluates a resolved sequence at a time in [0, duration) and reports its display list as `evaluate` prints it,
// nested lists flattened.
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

        return report(of: evaluator.displayList(of: sequence, at: time), at: time)
    }

    func report(
        of list: DisplayList,
        at time: Double
    ) -> EvaluationReport {
        EvaluationReport(time: time, size: list.size, items: flattener.items(of: list).map(EvaluationItem.init))
    }

    // MARK: - Private
}
