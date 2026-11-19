//
//  TargetFollower.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Follows a target in a video with the tracker provider, which reads only the media's pixels. The provider is given the
// part of the target inside the picture, and each quad it reports is carried back to the whole target by the motion
// fitted to it, so the quads stay those of the target as found. A target with no part inside is followed on no frame.
struct TargetFollower: Sendable {
    // MARK: - Property
    private let tracker: any TrackerProvider

    // MARK: - Initializer
    init(tracker: any TrackerProvider) {
        self.tracker = tracker
    }

    // MARK: - Public
    func follow(
        _ target: Rectangle,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>
    ) throws -> [TrackedFrame] {
        let bounds = file.size.map { Rectangle(x: 0, y: 0, width: $0.width, height: $0.height) }
        guard let inside = bounds.map({ target.intersection($0) }) ?? target else { return [] }

        let frames = try tracker.track(Quad(inside), in: file, atMediaTime: time, over: range)
        guard inside != target else { return frames }

        return frames.map { frame in
            let motion = TrackMotion(from: Quad(inside), to: frame.quad)
            return TrackedFrame(time: frame.time, quad: Quad(target).applying(motion.transform))
        }
    }

    // MARK: - Private
}
