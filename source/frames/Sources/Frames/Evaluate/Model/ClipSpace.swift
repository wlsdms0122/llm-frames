//
//  ClipSpace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The coordinate space a clip's positions and areas are written in, at one instant. `transform` maps that space to
// output pixels of the list the clip is drawn in, the identity for an unparented clip; it is any affine map, as a
// parent may scale its axes apart and mirror. `frame` is the list's frame, what an adjustment without a mask covers,
// and `clock` the parent's media clock, which a tracked clip follows. A tracked clip's keyframes are each brought back
// to the instant through its track, so `area`, `point`, `points`, `masks` and `anchor` answer in the clip's values'
// coordinates, and `tracked(by:at:)` is the space that maps those to output pixels: the track's motion, then this
// space's map. `areas` gives the clip areas of the clip drawn in the space at the instant, and a space without it takes
// a clip area as an empty rectangle at the origin.
struct ClipSpace: Sendable {
    // MARK: - Property
    let frame: Rectangle
    let transform: AffineTransform
    let clock: MediaClock?
    let areas: ClipAreaSampler?

    // MARK: - Initializer
    init(
        frame: Rectangle,
        transform: AffineTransform = .identity,
        clock: MediaClock? = nil,
        areas: ClipAreaSampler? = nil
    ) {
        self.frame = frame
        self.transform = transform
        self.clock = clock
        self.areas = areas
    }

    // MARK: - Public
    func area(
        of areas: [Keyframe<GeometryArea>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Rectangle {
        let keyframes = self.areas?.rectangles(of: areas, at: time) ?? areas.map { $0.map(\.fixed) }
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.area(of: keyframes, on: clock, at: time)
    }

    func point(
        of points: [Keyframe<GeometryPoint>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Point {
        let keyframes = sampled(points, at: time)
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.point(of: keyframes, on: clock, at: time)
    }

    func points(
        of points: [Keyframe<[GeometryPoint]>],
        track: ResolvedTrack?,
        at time: Double
    ) -> [Point] {
        let keyframes = areas?.points(of: points, at: time) ?? points.map { $0.map { $0.map(\.fixed) } }
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.points(of: keyframes, on: clock, at: time)
    }

    func masks(
        of masks: [ResolvedMask],
        track: ResolvedTrack?,
        at time: Double
    ) -> [MaskSample] {
        let masks = areas.map { areas in masks.map { $0.taking(areas, at: time) } } ?? masks
        guard let track, let clock else { return masks.map { $0.sampled(at: time) } }

        return track.masks(of: masks, on: clock, at: time)
    }

    // A box clip's anchor point, its `position`.
    func anchor(
        of box: ResolvedBox,
        track: ResolvedTrack?,
        at time: Double
    ) -> Point {
        let anchors = sampled(box.position, at: time)
        guard let track, let clock else { return anchors.value(at: time) }

        return track.point(of: anchors, on: clock, at: time)
    }

    // The space with the clip areas of `clip`, the clip drawn in it.
    func drawing(
        _ clip: ResolvedClip,
        of sequence: ResolvedSequence
    ) -> ClipSpace {
        ClipSpace(frame: frame, transform: transform, clock: clock, areas: ClipAreaSampler(sequence: sequence, clip: clip))
    }

    func tracked(
        by track: ResolvedTrack?,
        at time: Double
    ) -> ClipSpace {
        guard let track, let clock else { return self }

        return ClipSpace(
            frame: frame,
            transform: track.transform(on: clock, at: time).concatenating(transform),
            clock: clock,
            areas: areas
        )
    }

    // MARK: - Private
    private func sampled(
        _ points: [Keyframe<GeometryPoint>],
        at time: Double
    ) -> [Keyframe<Point>] {
        areas?.points(of: points, at: time) ?? points.map { $0.map(\.fixed) }
    }
}
