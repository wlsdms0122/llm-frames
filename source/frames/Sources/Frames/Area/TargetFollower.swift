//
//  TargetFollower.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Follows a target in a video with the tracker provider, which reads only the media's pixels (FRAMES-23 `track`). The
// provider is given the target's quad where it lies inside the picture, and otherwise the rectangle that bounds the
// part inside, and each quad r it reports for what it was given, g, is carried to the whole target by H(g → r). A
// target with no part inside is followed on no frame. A frame whose carried quad is not strictly convex, or runs the
// other way round than the target, is not followed, and the track ends before it in that direction.
struct TargetFollower: Sendable {
    // MARK: - Property
    private let tracker: any TrackerProvider

    // MARK: - Initializer
    init(tracker: any TrackerProvider) {
        self.tracker = tracker
    }

    // MARK: - Public
    // `colorSpace` is the one the media are read in where the clip writes one.
    func follow(
        _ target: Quad,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>,
        colorSpace: ColorSpace?
    ) throws -> [TrackedFrame] {
        guard let orientation = target.orientation, let given = given(target, in: file) else { return [] }

        let frames = try tracker.track(given, in: file, atMediaTime: time, over: range, colorSpace: colorSpace)
        let carried = given == target
            ? frames.map { frame in (time: frame.time, quad: Optional(frame.quad)) }
            : frames.map { frame in
                (time: frame.time, quad: Homography(from: given, to: frame.quad).flatMap { $0.apply(to: target) })
            }

        return followed(carried, from: time, orientation: orientation)
    }

    // MARK: - Private
    // What the tracker is given: the target inside the picture, or the rectangle bounding its part inside.
    private func given(
        _ target: Quad,
        in file: MediaFile
    ) -> Quad? {
        guard let size = file.size else { return target }

        let picture = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        guard !target.isInside(picture) else { return target }

        return target.bounds(inside: picture).map(Quad.init)
    }

    // The frames walked out from the one shown at `time`, in each direction up to the first whose quad is not strictly
    // convex or runs the other way round than the target.
    private func followed(
        _ frames: [(time: Double, quad: Quad?)],
        from time: Double,
        orientation: Orientation
    ) -> [TrackedFrame] {
        let isFollowed = { (index: Int) in frames[index].quad?.orientation == orientation }
        guard
            let start = frames.lastIndex(where: { $0.time.roundedTime <= time.roundedTime }) ?? frames.indices.first,
            isFollowed(start)
        else {
            return []
        }

        var first = start
        while first > frames.startIndex, isFollowed(first - 1) {
            first -= 1
        }
        var last = start
        while last < frames.endIndex - 1, isFollowed(last + 1) {
            last += 1
        }

        return frames[first...last].compactMap { frame in frame.quad.map { TrackedFrame(time: frame.time, quad: $0) } }
    }
}
