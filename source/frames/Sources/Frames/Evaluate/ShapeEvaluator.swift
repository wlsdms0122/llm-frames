//
//  ShapeEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates a shape clip at an instant into its item in output pixels of its list. A shape on an area is drawn in its
// space's coordinates and carried whole by its tracked motion and P(t), its lengths divided by their scale so they
// stay; one without an area is drawn on the frame in output pixels. `reveal` acts by what receives it: a box's border
// is drawn around as its `trim`, a fill is wiped from the `revealFrom` side, a dim's hole closes in from the whole
// frame to the area, and an arrow is nudged and grows from its tail. Scale, rotation and the offset act about the
// centre of the shape's box: its area, or for an arrow the box it fills from tail to head.
struct ShapeEvaluator: Sendable {
    // MARK: - Property
    private let drawer = ShapeDrawer()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func items(
        of drawing: ShapeDrawing,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> [DisplayItem] {
        let tracked = space.tracked(by: clip.track, at: time)
        let area = clip.area.map { space.area(of: $0, track: clip.track, at: time) }
        // A space at scale 0, a parent entering from 0 or keyed to 0, flattens the shape to a point, and its lengths
        // cannot be kept there, so it draws nothing.
        guard area == nil || tracked.scale > 0 else { return [] }

        let laid = laid(drawing, on: area, sample: sample, in: tracked)
        let frame = frame(of: laid.presentation.transform, covering: space.frame)

        return [item(of: laid.content, area: area, frame: frame, sample: sample, presentation: laid.presentation)]
    }

    // The map from the space the shape's area is written in to output pixels, which its children are carried by.
    func transform(
        of drawing: ShapeDrawing,
        clip: ResolvedClip,
        sample: ClipSample,
        in space: ClipSpace,
        at time: Double
    ) -> AffineTransform {
        let tracked = space.tracked(by: clip.track, at: time)
        let area = clip.area.map { space.area(of: $0, track: clip.track, at: time) }
        // At scale 0 every point of the space lands on one, and the shape's own motion leaves it there.
        guard area == nil || tracked.scale > 0 else { return tracked.transform }

        let transform = laid(drawing, on: area, sample: sample, in: tracked).presentation.transform

        return area == nil ? tracked.transform.concatenating(transform) : transform
    }

    // MARK: - Private
    private func laid(
        _ drawing: ShapeDrawing,
        on area: Rectangle?,
        sample: ClipSample,
        in space: ClipSpace
    ) -> (content: ShapeContent, presentation: ItemPresentation) {
        guard let area else {
            let drawn = drawer.content(of: drawing, on: space.frame, scale: 1)
            let presentation = ItemPresentation(area: drawn.box, opacity: sample.opacity, motion: sample.animation.motion)
            return (drawn.content, presentation)
        }

        let drawn = drawer.content(of: drawing, on: area, scale: space.scale)
        let presentation = ItemPresentation(
            area: drawn.box,
            opacity: sample.opacity,
            motion: sample.animation.motion,
            carriedBy: space.transform
        )
        return (drawn.content, presentation)
    }

    // The list's frame in the item's own coordinates, as the rectangle around its corners carried back, which is what
    // a dim darkens. A transform that flattens the plane draws nothing, so the frame itself serves.
    private func frame(
        of transform: AffineTransform,
        covering frame: Rectangle
    ) -> Rectangle {
        guard let inverse = transform.inverse else { return frame }

        let corners = inverse.apply(toCornersOf: frame)
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        let minX = xs.min() ?? frame.x
        let minY = ys.min() ?? frame.y
        return Rectangle(x: minX, y: minY, width: (xs.max() ?? frame.maxX) - minX, height: (ys.max() ?? frame.maxY) - minY)
    }

    // The item of what the drawer laid the shape as, on the shape's area or the frame. `area` is the shape's own area,
    // nil without one, and `frame` the list's frame in the item's coordinates.
    private func item(
        of content: ShapeContent,
        area: Rectangle?,
        frame: Rectangle,
        sample: ClipSample,
        presentation: ItemPresentation
    ) -> DisplayItem {
        let reveal = sample.animation.reveal

        switch content {
        case let .box(rectangle, width, radius, color):
            let stroke = StrokeItem(
                rectangle: rectangle,
                radius: radius,
                width: width,
                color: color,
                trim: reveal.amount
            )
            return DisplayItem(
                transform: presentation.transform,
                opacity: presentation.opacity,
                blend: sample.blend,
                content: .stroke(stroke)
            )

        case let .fill(rectangle, color):
            return DisplayItem(
                transform: presentation.transform,
                opacity: presentation.opacity,
                blend: sample.blend,
                reveal: reveal.rectangle(wiping: rectangle, from: sample.animation.revealFrom),
                content: .fill(FillItem(rectangle: rectangle, color: color))
            )

        case let .dim(_, color):
            // Without an area a dim darkens the whole frame.
            let hole = area.map { area in
                RoundedRectangle(rectangle: reveal.hole(closingFrom: frame, to: area), radius: 0)
            }
            let fill = FillItem(rectangle: frame, color: color, hole: hole)
            return DisplayItem(
                transform: presentation.transform,
                opacity: presentation.opacity,
                blend: sample.blend,
                content: .fill(fill)
            )

        case let .arrow(tail, tip, width, head, color):
            let item = ArrowItem(tail: tail, head: tip, width: width, headSize: head, color: color)
                .moved(by: sample.animation.motion)
            return DisplayItem(
                transform: presentation.transform,
                opacity: presentation.opacity,
                blend: sample.blend,
                content: .arrow(item)
            )
        }
    }
}
