//
//  ResolvedClip+CornerPin.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A clip's corner pin at a time (FRAMES-27), in the space its corner pin is written in. Q'(t) is its keyframes, each
// brought back to the track's frame at its own time when it follows its parent's media as `Track.broughtBack` brings
// it back, a static one being on the track's frame already, then each clip area taken at the time and the keyframes
// interpolated point by point; an untracked corner pin is Q(t), its keyframes interpolated. Its corner pin bounds bound
// Q'(t). The corner pin its group carries is Q(t) = M(t)⁻¹ H(t) Q'(t), inside the clip's transform M(t), and it draws
// nothing where its box has no area, a corner of Q'(t) does not lie in front of the horizon of H(t), or H(t) Q'(t) is
// not strictly convex. Q'(t) is read at the time's instant on T's side of its jumps, and H(t) and M(t) are those of the
// media frame shown at T, the time's `frameTime`, as every tracked value is carried (FRAMES-29). `clock` is the clock
// of the media the clip follows.
extension ResolvedClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func writtenCornerPin(
        areas: ClipAreaSampler?,
        clock: MediaClock?,
        at time: SampleTime
    ) -> Quad? {
        guard let cornerPin else { return nil }

        let brought = cornerPin.points.carried(
            keyframe: { points, at in broughtBack(points, on: clock, at: at) },
            onTrackFrame: { $0 }
        )
        let keyframes = areas?.quads(of: brought, at: time) ?? brought.mapValues { $0.sampled(\.fixed) }
        return keyframes.value(at: time)
    }

    func cornerPinBounds(
        areas: ClipAreaSampler?,
        clock: MediaClock?,
        at time: SampleTime
    ) -> Rectangle? {
        writtenCornerPin(areas: areas, clock: clock, at: time).map { Rectangle(bounding: $0.corners) }
    }

    // Nil where the corner pin draws nothing at the time, `box` being the size of the clip's box B there.
    func drawnCornerPin(
        box: Size,
        areas: ClipAreaSampler?,
        clock: MediaClock?,
        at time: SampleTime
    ) -> Quad? {
        guard box.width > 0, box.height > 0, let written = writtenCornerPin(areas: areas, clock: clock, at: time) else {
            return nil
        }
        guard let track = parentTrack, let clock else { return written.isStrictlyConvex ? written : nil }

        let mediaTime = clock.mediaTime(atSequenceTime: time.frameTime)
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
    // A keyframe brought back to the track's frame at its own time, corner by corner, where its clip follows its
    // parent's media; resolve has checked that every keyframe comes back.
    private func broughtBack(
        _ points: GeometryQuad,
        on clock: MediaClock?,
        at time: Double
    ) -> GeometryQuad {
        guard let track = parentTrack, let clock else { return points }

        return track.track.broughtBack(points, atMediaTime: clock.mediaTime(atSequenceTime: time)) ?? points
    }
}
