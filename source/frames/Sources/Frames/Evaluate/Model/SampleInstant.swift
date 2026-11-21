//
//  SampleInstant.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One instant of a frame's exposure as the clips of one sequence read it (FRAMES-29): `instant`, the time it stands
// for, and `frameTime`, the frame's instant T, both on that sequence's clock, and `reads`, the record of what the
// frame's samples read. Outside a sample of a frame with motion blur the instant is T and there is no record.
struct SampleInstant: Sendable {
    // MARK: - Property
    let instant: Double
    let frameTime: Double
    let reads: MotionBlurReads?

    var isSample: Bool {
        reads != nil
    }

    // MARK: - Initializer
    init(frameTime: Double) {
        self.instant = frameTime
        self.frameTime = frameTime
        self.reads = nil
    }

    init(
        instant: Double,
        frameTime: Double,
        reads: MotionBlurReads
    ) {
        self.instant = instant
        self.frameTime = frameTime
        self.reads = reads
    }

    // MARK: - Public
    // Reads the time an owner's values are read at, and records in `reads` a read of a value owned by a clip with
    // `motionBlur`: the instant where the owner has `motionBlur` and T where it has not, each held in the owner's window,
    // with T held in that window as the side its reads clamp to.
    func readTime(
        ownedBy isMotionBlurred: Bool,
        in window: TimeRange
    ) -> SampleTime {
        if isMotionBlurred {
            reads?.recordRead()
        }

        return SampleTime(
            instant: window.held(isMotionBlurred ? instant : frameTime),
            frameTime: window.held(frameTime),
            sample: self
        )
    }

    // MARK: - Private
}
