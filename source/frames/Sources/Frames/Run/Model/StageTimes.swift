//
//  StageTimes.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The seconds spent in each stage of a run, 0 for a stage that ran no work.
package struct StageTimes: Equatable, Sendable {
    // MARK: - Property
    private var seconds: [RunStage: Double]

    // The seconds of the stages the render's own thread runs.
    package var renderThreadSeconds: Double {
        RunStage.allCases.filter(\.isOnRenderThread).reduce(0) { $0 + self[$1] }
    }

    // MARK: - Initializer
    package init() {
        self.seconds = [:]
    }

    // MARK: - Public
    package subscript(_ stage: RunStage) -> Double {
        seconds[stage] ?? 0
    }

    package mutating func add(
        _ seconds: Double,
        to stage: RunStage
    ) {
        self.seconds[stage, default: 0] += seconds
    }

    package static func + (lhs: StageTimes, rhs: StageTimes) -> StageTimes {
        var sum = lhs
        for stage in RunStage.allCases {
            sum.add(rhs[stage], to: stage)
        }

        return sum
    }

    // MARK: - Private
}
