//
//  SampleInstant.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One instant of a frame's exposure as the clips of one sequence read it (FRAMES-29): `time`, the instant, and
// `frameTime`, the frame's instant T, both on that sequence's clock. While a sample is evaluated it is `current`. A
// value is then read at the instant where its owner has `motionBlur` and at T where it has not, each held in its
// owner's window, and `side` is T held in the window of the owner being read, the side every reader of a parameter
// that takes time clamps the read to. With none current, every value is read at the time it is asked for.
struct SampleInstant: Sendable {
    // MARK: - Property
    @TaskLocal static var current: SampleInstant?

    let time: Double
    let frameTime: Double
    let side: Double
    let reads: OwnerReads

    // MARK: - Initializer
    init(
        time: Double,
        frameTime: Double,
        side: Double? = nil,
        reads: OwnerReads
    ) {
        self.time = time
        self.frameTime = frameTime
        self.side = side ?? frameTime
        self.reads = reads
    }

    // MARK: - Public
    // The time a value its owner holds is read at, `time` with none current.
    static func valueTime(
        ownedBy isMotionBlurred: Bool,
        in window: TimeRange,
        at time: Double
    ) -> Double {
        guard let current else { return time }

        if isMotionBlurred {
            current.reads.markMotionBlur()
        }
        return window.held(isMotionBlurred ? current.time : current.frameTime)
    }

    // Reads what an owner holds at its value time, with T's side held in its window.
    static func reading<Result>(
        ownedBy isMotionBlurred: Bool,
        in window: TimeRange,
        at time: Double,
        _ read: (Double) -> Result
    ) -> Result {
        guard let current else { return read(time) }

        let valueTime = valueTime(ownedBy: isMotionBlurred, in: window, at: time)
        let owned = SampleInstant(
            time: current.time,
            frameTime: current.frameTime,
            side: window.held(current.frameTime),
            reads: current.reads
        )

        return $current.withValue(owned) { read(valueTime) }
    }

    // T's side for a read at `time`, `time` itself with none current.
    static func side(at time: Double) -> Double {
        current?.side ?? time
    }

    // MARK: - Private
}
