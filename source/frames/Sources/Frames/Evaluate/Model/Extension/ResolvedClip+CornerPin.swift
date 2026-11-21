//
//  ResolvedClip+CornerPin.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A clip's corner pin at a time (FRAMES-27), in the space its corner pin is written in. Q'(t) is its keyframes, each
// clip area taken at the time, brought back through the inverse of its track's homography at its own time when it
// follows its parent's media, a static one being on the track's frame already, then interpolated point by point; an
// untracked corner pin is Q(t), its keyframes interpolated. Its corner pin bounds bound Q'(t). The corner pin its group
// carries is Q(t) = M(t)⁻¹ H(t) Q'(t), inside the clip's transform M(t), and it draws nothing where its box has no
// area, a corner of Q'(t) does not lie in front of the horizon of H(t), or H(t) Q'(t) is not strictly convex. `clock`
// is the clock of the media the clip follows.
extension ResolvedClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func writtenCornerPin(
        areas: ClipAreaSampler?,
        clock: MediaClock?,
        at time: Double
    ) -> Quad? {
        guard let cornerPin else { return nil }

        let keyframes = areas?.points(of: cornerPin.points, at: time)
            ?? cornerPin.points.mapValues { points in points.map(\.fixed) }
        let brought = keyframes.carried(
            keyframe: { points, at in broughtBack(points, on: clock, at: at) },
            onTrackFrame: { $0 }
        )
        let points = brought.value(at: time)
        guard points.count == 4 else { return nil }

        return Quad(topLeft: points[0], topRight: points[1], bottomRight: points[2], bottomLeft: points[3])
    }

    func cornerPinBounds(
        areas: ClipAreaSampler?,
        clock: MediaClock?,
        at time: Double
    ) -> Rectangle? {
        writtenCornerPin(areas: areas, clock: clock, at: time).map { Rectangle(bounding: $0.corners) }
    }

    // Nil where the corner pin draws nothing at the time, `box` being the size of the clip's box B there.
    func drawnCornerPin(
        box: Size,
        areas: ClipAreaSampler?,
        clock: MediaClock?,
        at time: Double
    ) -> Quad? {
        guard box.width > 0, box.height > 0, let written = writtenCornerPin(areas: areas, clock: clock, at: time) else {
            return nil
        }
        guard let track = parentTrack, let clock else { return written.isStrictlyConvex ? written : nil }

        let mediaTime = clock.mediaTime(atSequenceTime: time)
        guard
            let homography = track.track.homography(atMediaTime: mediaTime),
            let carried = homography.apply(to: written, inFrontOf: track.track.target),
            carried.isStrictlyConvex
        else {
            return nil
        }

        let motion = track.motion(atMediaTime: mediaTime)
        return Quad(
            topLeft: motion.bringBack(carried.topLeft),
            topRight: motion.bringBack(carried.topRight),
            bottomRight: motion.bringBack(carried.bottomRight),
            bottomLeft: motion.bringBack(carried.bottomLeft)
        )
    }

    // MARK: - Private
    // A keyframe's points brought back through the inverse of the homography of the frame its time shows, in front of
    // whose horizon resolve has checked they lie. A keyframe holding a clip area is the named clip's box at the time
    // and is not brought back, and neither is an untracked corner pin.
    private func broughtBack(
        _ points: [Point],
        on clock: MediaClock?,
        at time: Double
    ) -> [Point] {
        guard
            let track = parentTrack,
            let clock,
            points.count == 4,
            cornerPin?.points.values.contains(where: { $0.contains { $0.clipArea != nil } }) != true,
            let homography = track.track.homography(atMediaTime: clock.mediaTime(atSequenceTime: time)),
            let frame = homography.apply(to: track.track.target)
        else {
            return points
        }

        let pin = Quad(topLeft: points[0], topRight: points[1], bottomRight: points[2], bottomLeft: points[3])
        return homography.inverse.apply(to: pin, inFrontOf: frame)?.corners ?? points
    }
}
