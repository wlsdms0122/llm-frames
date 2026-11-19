//
//  ShapeEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The outset grows only the outline a shape draws: its anchor point, the space its children see and the fractions of
// its box its animation moves it by are taken on the box as written. A shape placed by its geometry is carried whole by
// its parent's map, so its lengths (outset, radius, stroke width, shadow) are divided by that map's scale to keep the
// parent's scale out of them.
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
        at time: Double
    ) -> [DisplayItem] {
        // A space at scale 0 flattens a shape placed by its geometry to a point, where its lengths cannot be kept, so
        // it draws nothing.
        guard let laid = laid(shape, clip: clip, sample: sample, in: space, at: time) else { return [] }

        let trim = shape.trim.value(at: time)
        let fill: Color? = if case let .form(_, color) = shape.fill.sampled(at: time, as: LookStructureTable.fill) {
            color.color
        } else {
            nil
        }
        let path = PathItem(
            geometry: laid.geometry,
            fill: fill,
            stroke: PathStroke(sampled: shape.stroke.sampled(at: time, as: LookStructureTable.stroke)).map { stroke in
                PathStroke(
                    width: stroke.width / laid.scale,
                    color: stroke.color,
                    join: stroke.join,
                    cap: stroke.cap,
                    start: stroke.start,
                    end: stroke.end
                )
            },
            trim: Trim(start: min(max(trim.start, 0), 1), end: min(max(trim.end, 0), 1)),
            shadow: DropShadow(sampled: shape.shadow.sampled(at: time, as: LookStructureTable.shadow)).map { shadow in
                DropShadow(
                    radius: shadow.radius / laid.scale,
                    offset: Point(x: shadow.offset.x / laid.scale, y: shadow.offset.y / laid.scale),
                    color: shadow.color
                )
            }
        )

        return [DisplayItem(
            transform: laid.transform,
            opacity: laid.opacity,
            blend: sample.blend,
            reveal: sample.animation.reveal.rectangle(wiping: receiverBox(of: path), from: sample.animation.revealFrom),
            content: .path(path)
        )]
    }

    // At a space scale of 0 every point lands on one whatever the shape's own motion, so the space's map stands in.
    func transform(
        of shape: ResolvedShape,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> AffineTransform {
        laid(shape, clip: clip, sample: sample, in: space, at: time)?.transform
            ?? space.tracked(by: clip.parentTrack, at: time).transform
    }

    // MARK: - Private
    // `scale` is what the item's lengths are divided by.
    private func laid(
        _ shape: ResolvedShape,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> (geometry: PathGeometry, transform: AffineTransform, opacity: Double, scale: Double)? {
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        let geometry: PathGeometry
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
            guard tracked.scale > 0 else { return nil }

            bounds = space.area(of: area, track: clip.parentTrack, at: time)
            placement = areaPlacement
            let drawn = bounds.grown(by: length(outset, at: time) / tracked.scale)
            let radius = length(shape.radius, at: time) / tracked.scale
            geometry = shape.kind == .ellipse ? .ellipse(drawn) : .rect(drawn, radius: radius)

        case let .points(keyframes, isClosed, pointsPlacement):
            guard tracked.scale > 0 else { return nil }

            let points = space.points(of: keyframes, track: clip.parentTrack, at: time)
            bounds = Rectangle(bounding: points)
            placement = pointsPlacement
            geometry = .polyline(points, isClosed: isClosed)
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

        return (geometry, transform, sample.opacity * motion.value(of: .opacity), tracked.scale)
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
        at time: Double
    ) -> (geometry: PathGeometry, transform: AffineTransform, opacity: Double, scale: Double) {
        let size = Size(width: width.value(at: time), height: height.value(at: time))
        let anchor = Point(
            x: box.size.width > 0 ? box.anchor.x * size.width / box.size.width : 0,
            y: box.size.height > 0 ? box.anchor.y * size.height / box.size.height : 0
        )
        let tracked = space.tracked(by: clip.parentTrack, at: time)
        let point = tracked.transform.apply(to: space.anchor(of: box, track: clip.parentTrack, at: time))
        let values = KeyframedValues(
            position: Point(x: point.x - anchor.x, y: point.y - anchor.y),
            scale: clip.scale.map { $0.value(at: time) } ?? 1,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + tracked.rotation,
            opacity: sample.opacity
        )
        let presentation = ItemPresentation(box: size, anchor: anchor, values: values, motion: sample.animation.motion)
        let outline = Rectangle(x: 0, y: 0, width: size.width, height: size.height).grown(by: length(outset, at: time))
        let geometry: PathGeometry = shape.kind == .ellipse
            ? .ellipse(outline)
            : .rect(outline, radius: length(shape.radius, at: time))

        return (geometry, presentation.transform, presentation.opacity, 1)
    }

    // A radius or an outset at a time, 0 where the shape has none.
    private func length(
        _ value: TimedValue,
        at time: Double
    ) -> Double {
        value.sampled(at: time, as: LookStructureTable.length).number ?? 0
    }

    private func receiverBox(of path: PathItem) -> Rectangle {
        let drawn = path.drawnBounds()
        guard let shadow = path.shadow else { return drawn }

        return drawn.union(shadow.castBounds(of: drawn))
    }
}
