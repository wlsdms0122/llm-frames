//
//  SampleInstant.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One instant of a frame's exposure as the clips of one sequence read it (FRAMES-29): `time`, the instant, and
// `frameTime`, the frame's instant T, both on that sequence's clock, and `reads`, the record of what the frame's samples
// read. Outside a sample of a frame with motion blur the instant is T and there is no record.
struct SampleInstant: Sendable {
    // MARK: - Property
    let time: Double
    let frameTime: Double
    let reads: OwnerReads?

    var isSample: Bool {
        reads != nil
    }

    // MARK: - Initializer
    init(frameTime: Double) {
        self.time = frameTime
        self.frameTime = frameTime
        self.reads = nil
    }

    init(
        time: Double,
        frameTime: Double,
        reads: OwnerReads
    ) {
        self.time = time
        self.frameTime = frameTime
        self.reads = reads
    }

    // MARK: - Public
    // The time an owner's values are read at: the instant where the owner has `motionBlur` and T where it has not, each
    // held in the owner's window, with T held in that window as the side its reads clamp to.
    func time(
        ownedBy isMotionBlurred: Bool,
        in window: TimeRange
    ) -> SampleTime {
        if isMotionBlurred {
            reads?.markMotionBlur()
        }

        return SampleTime(
            instant: window.held(isMotionBlurred ? time : frameTime),
            frameTime: window.held(frameTime),
            sample: self
        )
    }

    // MARK: - Private
}
