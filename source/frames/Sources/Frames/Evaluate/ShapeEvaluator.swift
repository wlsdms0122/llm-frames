//
//  ShapeEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates a shape clip at an instant into its item, in the coordinates of the space it is composited
// in. The shape is drawn on its area at the instant, or on the frame without one, and `reveal` acts by what receives
// it: a box's border is drawn around as its `trim`, a fill is wiped from the `revealFrom` side, a dim's hole closes in
// from the whole frame to the area, and an arrow is nudged and grows from its tail. Scale, rotation and the offset act
// about the centre of the shape's box: its area, or for an arrow the box it fills from tail to head.
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
        let area = clip.area.map { space.area(of: $0, track: clip.track, at: time) }
        let drawn = drawer.content(of: drawing, on: area ?? space.frame)
        let presentation = ItemPresentation(area: drawn.box, opacity: sample.opacity, motion: sample.animation.motion)
        return [item(of: drawn.content, area: area, in: space, sample: sample, presentation: presentation)]
    }

    // MARK: - Private
    // The item of what the drawer laid the shape as, on the shape's area or the frame. `area` is the shape's own area,
    // nil without one.
    private func item(
        of content: ShapeContent,
        area: Rectangle?,
        in space: ClipSpace,
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
                RoundedRectangle(rectangle: reveal.hole(closingFrom: space.frame, to: area), radius: 0)
            }
            let fill = FillItem(rectangle: space.frame, color: color, hole: hole)
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
