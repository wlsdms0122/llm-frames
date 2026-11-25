//
//  UnmarkedStages.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Marks no stage, for a run that no profiler watches.
package struct UnmarkedStages: StageMarker {
    // MARK: - Property
    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func interval<Result>(
        of stage: RunStage,
        _ work: () throws -> Result
    ) rethrows -> Result {
        try work()
    }

    // MARK: - Private
}
