//
//  RunRecorder.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Times a run of `render` on the render's own thread, from when it is made (FRAMES-23 Runs): each stage the render loop
// runs itself, less the time the decoder held the render's thread inside it, which is the decoder's own `decode` and
// `workingConversion` and its waiting on its reading ahead; the time spent in the encoder; and how far the run has
// drawn, which it hands to `progress` for every frame drawn. `clock` gives the seconds of a monotonic clock from an
// origin of its own. Used from the render's thread alone: what the decoder reads ahead on threads of its own runs
// inside no stage of it, so only the decoder's time on its caller's thread is taken from a stage.
package final class RunRecorder {
    // MARK: - Property
    private static let origin = ContinuousClock.now

    private let clock: () -> Double
    private let start: Double
    private let marker: any StageMarker
    private let progress: (RunProgress) -> Void

    package private(set) var stages = StageTimes()
    package private(set) var waitingOnEncoder: Double = 0

    // The wall time since the run began.
    package var elapsed: Double {
        clock() - start
    }

    // MARK: - Initializer
    package init(
        clock: @escaping () -> Double = RunRecorder.continuousSeconds,
        marker: any StageMarker = UnmarkedStages(),
        progress: @escaping (RunProgress) -> Void = { _ in }
    ) {
        self.clock = clock
        self.start = clock()
        self.marker = marker
        self.progress = progress
    }

    // MARK: - Public
    // The seconds of the continuous clock, which keeps counting while the machine sleeps, from its own origin.
    package static func continuousSeconds() -> Double {
        (ContinuousClock.now - origin).seconds
    }

    // Runs `work` as `stage`, adding its wall time less the time the decoder held this thread inside it.
    package func measure<Result>(
        _ stage: RunStage,
        reading decoder: any MediaDecoder,
        _ work: () throws -> Result
    ) rethrows -> Result {
        let held = decoder.readings().callerSeconds
        let begin = clock()
        defer {
            let elapsed = clock() - begin
            stages.add(elapsed - (decoder.readings().callerSeconds - held), to: stage)
        }

        return try marker.interval(of: stage, work)
    }

    // Runs `work`, a call into the encoder, as time spent waiting on it.
    package func measureWaitingOnEncoder<Result>(_ work: () throws -> Result) rethrows -> Result {
        let begin = clock()
        defer { waitingOnEncoder += clock() - begin }

        return try work()
    }

    package func drew(
        frame: Int,
        of frames: Int
    ) {
        progress(RunProgress(frame: frame, frames: frames, seconds: elapsed))
    }

    // MARK: - Private
}
