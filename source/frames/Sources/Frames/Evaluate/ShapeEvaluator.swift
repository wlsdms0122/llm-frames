//
//  ShapeEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The outset grows only the outline a shape draws: its anchor point, the space its children see and the fractions of
// its box its animation moves it by are taken on the box as written. A shape's lengths come out at its scale factor and
// not its parent's: its stroke width and shadow radius are written in output pixels, and the lengths its item's
// transform carries (outset, radius, shadow offset) at that size over the transform's length factor.
struct ShapeEvaluator: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func items(
        of shape: ResolvedShape,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: SampleTime
    ) -> [DisplayItem] {
        // A transform at scale 0 flattens the shape to a point, where its carried lengths cannot be kept, so it draws
        // nothing. In a sample of a frame with motion blur its item is there all the same, every carried length 0, since
        // whether an item is there is decided at T (FRAMES-29).
        guard
            let laid = laid(shape, clip: clip, sample: sample, in: space, at: time),
            let carried = laid.carried ?? (time.sample.isSample ? 0 : nil)
        else { return [] }

        let factor = sample.lengthFactor

        let trim = shape.trim.value(at: time)
        let path = PathItem(
            geometry: laid.geometry,
            fill: Paint(sampled: shape.fill.sampled(at: time, as: LookStructureTable.fill), box: laid.box),
            stroke: PathStroke(
                sampled: shape.stroke.sampled(at: time, as: LookStructureTable.stroke),
                factor: factor,
                carried: carried,
                box: laid.box,
                isSample: time.sample.isSample
            ),
            trim: Trim(start: min(max(trim.start, 0), 1), end: min(max(trim.end, 0), 1)),
            shadow: DropShadow(
                sampled: shape.shadow.sampled(at: time, as: LookStructureTable.shadow),
                factor: factor,
                carried: carried
            )
        )

        return [DisplayItem(
            transform: laid.transform,
            opacity: laid.opacity,
            blend: sample.blend,
            reveal: sample.animation.revealRectangle(wiping: receiverBox(of: path, carriedBy: laid.transform)),
            content: .path(path)
        )]
    }

    // At a scale of 0 every point lands on one, so the space's map stands in.
    func transform(
        of shape: ResolvedShape,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: SampleTime
    ) -> AffineTransform {
        laid(shape, clip: clip, sample: sample, in: space, at: time)?.transform
            ?? space.tracked(by: clip.parentTrack, at: time).transform
    }

    // MARK: - Private
    // `carried` is what a length the transform carries is multiplied by, nil where the transform flattens the plane;
    // the geometry then takes none. `box` is the shape's box as written, before its outset, in the geometry's
    // coordinates.
    private func laid(
        _ shape: ResolvedShape,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: SampleTime
    ) -> (geometry: PathGeometry, box: Rectangle, transform: AffineTransform, opacity: Double, carried: Double?)? {
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        let geometry: (Double) -> PathGeometry
        let bounds: Rectangle
        let placement: GeometryPlacement
        switch shape.geometry {
        case let .box(width, height, outset):
            // A box shape's entry carries its box.
            return clip.box.map { box in
                laid(
                    shape,
                    width: width,
                    height: height,
                    outset: outset,
                    box: box,
                    clip: clip,
                    sample: sample,
                    in: space,
                    at: time
                )
            }

        case let .area(area, outset, areaPlacement):
            bounds = space.area(of: area, track: clip.parentTrack, at: time)
            placement = areaPlacement
            geometry = { [kind = shape.kind, radius = shape.radius] carried in
                let drawn = bounds.grown(by: length(outset, at: time) * carried)
                return kind == .ellipse ? .ellipse(drawn) : .rect(drawn, radius: length(radius, at: time) * carried)
            }

        case let .points(keyframes, isClosed, pointsPlacement):
            let points = space.points(of: keyframes, track: clip.parentTrack, at: time)
            bounds = Rectangle(bounding: points)
            placement = pointsPlacement
            geometry = { _ in .polyline(points, isClosed: isClosed) }
        }

        let motion = sample.animation.motion
        let transform = AffineTransform(
            placing: bounds,
            anchor: placement.anchor,
            position: placement.position.map { space.point(of: $0, track: clip.parentTrack, at: time) },
            scale: sample.ownScale,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + motion.value(of: .rotation),
            moved: Point(x: motion.value(of: .x) * bounds.width, y: motion.value(of: .y) * bounds.height)
        ).concatenating(tracked.transform)
        let carried = carried(by: transform, sample: sample)

        return (geometry(carried ?? 0), bounds, transform, sample.opacity * motion.value(of: .opacity), carried)
    }

    // While the box changes size the anchor point stays the same fraction of it.
    private func laid(
        _ shape: ResolvedShape,
        width: [Keyframe<Double>],
        height: [Keyframe<Double>],
        outset: TimedValue,
        box: ResolvedBox,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: SampleTime
    ) -> (geometry: PathGeometry, box: Rectangle, transform: AffineTransform, opacity: Double, carried: Double?) {
        let size = Size(width: width.value(at: time), height: height.value(at: time))
        let anchor = Point(
            x: box.size.width > 0 ? box.anchor.x * size.width / box.size.width : 0,
            y: box.size.height > 0 ? box.anchor.y * size.height / box.size.height : 0
        )
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        let point = tracked.transform.apply(to: space.anchor(of: box, track: clip.parentTrack, at: time))
        let values = KeyframedValues(
            position: Point(x: point.x - anchor.x, y: point.y - anchor.y),
            scale: clip.scale.map { $0.value(at: time) } ?? .identity,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + tracked.transform.rotation,
            opacity: sample.opacity
        )
        let presentation = ItemPresentation(box: size, anchor: anchor, values: values, motion: sample.animation.motion)
        let carried = carried(by: presentation.transform, sample: sample)
        let box = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let outline = box.grown(by: length(outset, at: time) * (carried ?? 0))
        let geometry: PathGeometry = shape.kind == .ellipse
            ? .ellipse(outline)
            : .rect(outline, radius: length(shape.radius, at: time) * (carried ?? 0))

        return (geometry, box, presentation.transform, presentation.opacity, carried)
    }

    // A carried length at the clip's scale factor over the transform's length factor, nil where the transform
    // flattens the plane.
    private func carried(
        by transform: AffineTransform,
        sample: ClipSample
    ) -> Double? {
        let length = transform.lengthFactor
        guard length > 0 else { return nil }

        return sample.lengthFactor / length
    }

    private func length(
        _ value: TimedValue,
        at time: SampleTime
    ) -> Double {
        value.sampled(at: time, as: LookStructureTable.length).number ?? 0
    }

    private func receiverBox(
        of path: PathItem,
        carriedBy transform: AffineTransform
    ) -> Rectangle {
        let drawn = path.drawnBounds(carriedBy: transform)
        guard let shadow = path.shadow else { return drawn }

        return drawn.union(shadow.castBounds(of: drawn))
    }
}
