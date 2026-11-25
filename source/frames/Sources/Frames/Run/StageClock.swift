//
//  StageClock.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Times the stages a role runs itself, from any thread, by a monotonic clock, and marks each.
package final class StageClock: Sendable {
    // MARK: - Property
    private let marker: any StageMarker
    private let times = Locked(StageTimes())

    package var seconds: StageTimes {
        times.read { $0 }
    }

    // MARK: - Initializer
    package init(marker: any StageMarker) {
        self.marker = marker
    }

    // MARK: - Public
    // Runs `work` as `stage`, adding its wall time to the stage's.
    package func measure<Result>(
        _ stage: RunStage,
        _ work: () throws -> Result
    ) rethrows -> Result {
        let start = ContinuousClock.now
        defer {
            let elapsed = (ContinuousClock.now - start).seconds
            times.write { $0.add(elapsed, to: stage) }
        }

        return try marker.interval(of: stage, work)
    }

    // MARK: - Private
}
