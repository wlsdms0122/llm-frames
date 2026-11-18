//
//  ShapeEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Evaluates a shape clip at an instant into its one `path` item in output pixels of its list, and gives the map its
// children are carried by (FRAMES-10, FRAMES-20). A shape given by `width` and `height` is drawn in its box's own
// pixels as a title's box is: its anchor point goes where its parent's map carries its position, it turns by its own
// rotation and the map's, at its own scale, and its box is `w(t)` by `h(t)` with the anchor point held where it is, so
// its lengths stay as written. A shape placed by its geometry is drawn in the coordinates its geometry is written in,
// carried by its tracked motion and P(t) whole, with its own and its animation's scale and rotation about its anchor
// point, and its lengths divided by P(t)'s scale, so that after the transform they are the clip's own times its own and
// its animation's scale and not its parent's. `reveal` wipes the shape's receiver box from the animation's side.
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
        // A space at scale 0, a parent entering from 0 or keyed to 0, flattens a shape placed by its geometry to a
        // point, and its lengths cannot be kept there, so it draws nothing.
        guard let laid = laid(shape, clip: clip, sample: sample, in: space, at: time) else { return [] }

        let trim = shape.trim.value(at: time)
        let path = PathItem(
            geometry: laid.geometry,
            fill: shape.fill,
            stroke: shape.stroke.map { stroke in
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
            shadow: shape.shadow.map { shadow in
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

    // The map from the space the shape gives its children to output pixels: its box's own pixels for a shape given by
    // `width` and `height`, and the space its geometry is written in for one placed by its geometry, each carried by
    // the item's transform. At scale 0 every point of the space lands on one, and the shape's own motion leaves it there.
    func transform(
        of shape: ResolvedShape,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> AffineTransform {
        laid(shape, clip: clip, sample: sample, in: space, at: time)?.transform
            ?? space.tracked(by: clip.track, at: time).transform
    }

    // MARK: - Private
    // The outline in the item's own coordinates, the item's transform and opacity, and the scale the item's lengths
    // are divided by.
    private func laid(
        _ shape: ResolvedShape,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> (geometry: PathGeometry, transform: AffineTransform, opacity: Double, scale: Double)? {
        if let box = clip.box {
            return laid(shape, box: box, clip: clip, sample: sample, in: space, at: time)
        }

        let tracked = space.tracked(by: clip.track, at: time)
        guard tracked.scale > 0 else { return nil }

        let radius = shape.radius.value(at: time) / tracked.scale
        let geometry: PathGeometry
        let bounds: Rectangle
        if let area = shape.area {
            let rectangle = space.area(of: area, track: clip.track, at: time)
            geometry = shape.kind == .ellipse ? .ellipse(rectangle) : .rect(rectangle, radius: radius)
            bounds = rectangle
        } else if let keyframes = shape.points {
            let points = space.points(of: keyframes, track: clip.track, at: time)
            geometry = .polyline(points, isClosed: shape.isClosed ?? false)
            bounds = Rectangle(bounding: points)
        } else {
            return nil
        }

        let motion = sample.animation.motion
        let anchor = shape.anchor ?? bounds.center
        let position = shape.position.map { space.point(of: $0, track: clip.track, at: time) } ?? anchor
        let offset = Point(
            x: position.x - anchor.x + motion.value(of: .x) * bounds.width,
            y: position.y - anchor.y + motion.value(of: .y) * bounds.height
        )
        let scale = (clip.scale.map { $0.value(at: time) } ?? 1) * motion.value(of: .scale)
        let rotation = (clip.rotation.map { $0.value(at: time) } ?? 0) + motion.value(of: .rotation)
        let transform = AffineTransform(scale: scale, about: anchor)
            .concatenating(AffineTransform(rotation: rotation, about: anchor))
            .concatenating(AffineTransform(translation: offset))
            .concatenating(tracked.transform)

        return (geometry, transform, sample.opacity * motion.value(of: .opacity), tracked.scale)
    }

    // A box shape keeps its anchor point where it is while its box changes size: the anchor stays the same point of
    // the box, scaled with it.
    private func laid(
        _ shape: ResolvedShape,
        box: ResolvedBox,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> (geometry: PathGeometry, transform: AffineTransform, opacity: Double, scale: Double) {
        let size = Size(
            width: shape.width.map { $0.value(at: time) } ?? box.size.width,
            height: shape.height.map { $0.value(at: time) } ?? box.size.height
        )
        let anchor = Point(
            x: box.size.width > 0 ? box.anchor.x * size.width / box.size.width : 0,
            y: box.size.height > 0 ? box.anchor.y * size.height / box.size.height : 0
        )
        let tracked = space.tracked(by: clip.track, at: time)
        let point = tracked.transform.apply(to: space.anchor(of: box, track: clip.track, at: time))
        let values = KeyframedValues(
            position: Point(x: point.x - anchor.x, y: point.y - anchor.y),
            scale: clip.scale.map { $0.value(at: time) } ?? 1,
            rotation: (clip.rotation.map { $0.value(at: time) } ?? 0) + tracked.rotation,
            opacity: sample.opacity
        )
        let presentation = ItemPresentation(box: size, anchor: anchor, values: values, motion: sample.animation.motion)
        let outline = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let geometry: PathGeometry = shape.kind == .ellipse
            ? .ellipse(outline)
            : .rect(outline, radius: shape.radius.value(at: time))

        return (geometry, presentation.transform, presentation.opacity, 1)
    }

    // What the shape draws, in its own coordinates (FRAMES-14): its outline's box grown by half its stroke, or by the
    // half width of an arrowhead's base where it has one, united with its shadow's box, moved by the shadow's offset
    // and grown by three times its radius, where the blur has all but faded.
    private func receiverBox(of path: PathItem) -> Rectangle {
        let outline = switch path.geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            rectangle

        case let .polyline(points, _):
            Rectangle(bounding: points)
        }
        let growth = path.stroke.map { stroke in
            stroke.start == .arrow || stroke.end == .arrow ? stroke.width * 2 : stroke.width / 2
        } ?? 0
        let drawn = outline.grown(by: growth)
        guard let shadow = path.shadow else { return drawn }

        let cast = Rectangle(
            x: drawn.x + shadow.offset.x,
            y: drawn.y + shadow.offset.y,
            width: drawn.width,
            height: drawn.height
        )
        return drawn.union(cast.grown(by: shadow.radius * 3))
    }
}
