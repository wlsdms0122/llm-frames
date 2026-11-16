//
//  ShapeEvaluator.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Evaluates a shape clip at an instant into its item and its label's, in the coordinates of the space it is composited
// in. The shape is drawn on its area at the instant, or on the room without one, and `reveal` acts by what receives
// it: a box's border is drawn around as its `trim`, a fill is wiped from the `revealFrom` side, a dim's hole closes in
// from the whole room to the area, and an arrow is nudged and grows from its tail. Scale, rotation and the offset act
// about the centre of the shape's box: its area, or for an arrow the box it fills from tail to head.
struct ShapeEvaluator: Sendable {
    // MARK: - Property
    private let animationSampler = AnimationSampler()
    private let drawer = ShapeDrawer()
    private let sideFinder = LabelSideFinder()

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
        let shapeArea = area ?? space.room
        let box = drawer.content(of: drawing, on: shapeArea).box
        let presentation = ItemPresentation(area: box, opacity: sample.opacity, motion: sample.animation.motion)
        let shape = item(of: drawing, area: area, in: space, sample: sample, presentation: presentation)
        guard let label = clip.label else { return [shape] }

        return [shape, labelItem(of: label, beside: box, sample: sample, presentation: presentation, at: time)]
    }

    // MARK: - Private
    private func item(
        of drawing: ShapeDrawing,
        area: Rectangle?,
        in space: ClipSpace,
        sample: ClipSample,
        presentation: ItemPresentation
    ) -> DisplayItem {
        let shapeArea = area ?? space.room
        let reveal = sample.animation.reveal

        switch drawing {
        case let .box(width, radius, color):
            let stroke = StrokeItem(
                rectangle: shapeArea,
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

        case let .fill(color):
            return DisplayItem(
                transform: presentation.transform,
                opacity: presentation.opacity,
                blend: sample.blend,
                reveal: reveal.rectangle(wiping: shapeArea),
                content: .fill(FillItem(rectangle: shapeArea, color: color))
            )

        case let .dim(color):
            // Without an area a dim darkens the whole room.
            let hole = area.map { area in
                RoundedRectangle(rectangle: reveal.hole(closingFrom: space.room, to: area), radius: 0)
            }
            let fill = FillItem(rectangle: space.room, color: color, hole: hole)
            return DisplayItem(
                transform: presentation.transform,
                opacity: presentation.opacity,
                blend: sample.blend,
                content: .fill(fill)
            )

        case let .arrow(side, length, width, head, color):
            let arrow = Arrow(pointingAt: shapeArea, from: side, length: length, breadth: max(head, width))
            let item = ArrowItem(arrow: arrow, width: width, headSize: head, color: color)
                .moved(by: sample.animation.motion)
            return DisplayItem(
                transform: presentation.transform,
                opacity: presentation.opacity,
                blend: sample.blend,
                content: .arrow(item)
            )
        }
    }

    // The label outside the shape's box on its side, touching it and centred along it, drawn in its text's own pixels.
    // It takes the shape's transform and opacity, and its own animation over the shape's visible window on top, about
    // the centre of its own box and in multiples of its size, with its own reveal.
    private func labelItem(
        of label: ResolvedLabel,
        beside box: Rectangle,
        sample: ClipSample,
        presentation: ItemPresentation,
        at time: Double
    ) -> DisplayItem {
        let size = label.text.size
        let rectangle = sideFinder.rectangle(of: size, beside: box, on: label.side)
        let own = animationSampler.sample(of: label.animation, in: sample.window, at: time)
        let ownPresentation = ItemPresentation(area: rectangle, opacity: 1, motion: own.motion)

        return DisplayItem(
            transform: AffineTransform(mapping: size, onto: rectangle)
                .concatenating(ownPresentation.transform)
                .concatenating(presentation.transform),
            opacity: presentation.opacity * ownPresentation.opacity,
            blend: sample.blend,
            reveal: own.reveal.rectangle(wiping: Rectangle(x: 0, y: 0, width: size.width, height: size.height)),
            content: .glyphs(GlyphsItem(text: label.text))
        )
    }
}
