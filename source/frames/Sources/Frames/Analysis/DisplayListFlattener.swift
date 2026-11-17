//
//  DisplayListFlattener.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Flattens a display list into what each of its items covers of the output frame, bottom first. A picture of a nested
// list is replaced by that list's background and items, carried through the picture's source rect, destination and
// transform and cut by its mask, reveal and destination, so they cover only what the picture shows. What an item
// covers follows its shape where that is a rectangle: a picture's destination, a fill less its hole, a stroke's band
// about its edge, an arrow's shaft and head, a glyphs item's box, and an adjustment's rect or its list's frame.
// Rounded corners, trims and mattes are left out.
struct DisplayListFlattener: Sendable {
    // MARK: - Property
    // A source rect with no width or height has nothing to show, so it maps everything to one point.
    private static let collapsed = AffineTransform(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0)

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The list's background comes first, unless it is transparent and draws nothing.
    func items(of list: DisplayList) -> [FlattenedItem] {
        items(of: list, state: GraphicsState(transform: .identity, clips: [], opacity: 1, origin: nil))
    }

    // MARK: - Private
    private func items(
        of list: DisplayList,
        state: GraphicsState
    ) -> [FlattenedItem] {
        let frame = Rectangle(x: 0, y: 0, width: list.size.width, height: list.size.height)
        // A list is drawn at its own size, so nothing of it shows outside its frame.
        let state = state.clipped(to: frame)
        // `#RRGGBBAA`, so a transparent background ends in an alpha of 00.
        let background = list.background.hex.hasSuffix("00")
            ? []
            : [FlattenedItem(
                origin: state.origin,
                opacity: state.opacity,
                coverage: state.covered(ItemCoverage(pieces: [ConvexPolygon(rectangle: frame)]))
            )]

        return background + list.items.flatMap { item in items(of: item, frame: frame, state: state) }
    }

    // `frame` is the frame of the list the item is in, in that list's coordinates.
    private func items(
        of item: DisplayItem,
        frame: Rectangle,
        state: GraphicsState
    ) -> [FlattenedItem] {
        let own = state.holding(item)
        guard case let .picture(picture) = item.content else {
            let coverage = own.covered(shape(of: item.content, frame: frame))
            return [FlattenedItem(origin: own.origin, opacity: own.opacity, coverage: coverage)]
        }

        switch picture.source {
        case let .media(media):
            // Without a source rect the picture shows the whole frame, whose size in pixels is not known here.
            let transform = picture.rectangle.flatMap { rectangle in
                own.transform.inverse.map { $0.concatenating(transform(from: picture.destination, onto: rectangle)) }
            }
            let placement = MediaPlacement(frame: media, transform: transform)
            let coverage = own.covered(shape(of: item.content, frame: frame))
            return [FlattenedItem(origin: own.origin, opacity: own.opacity, coverage: coverage, media: placement)]

        case let .displayList(list):
            let rectangle = picture.rectangle
                ?? Rectangle(x: 0, y: 0, width: list.size.width, height: list.size.height)
            let nested = own.nesting(
                rectangle: rectangle,
                transform: transform(from: rectangle, onto: picture.destination),
                destination: picture.destination
            )
            return items(of: list, state: nested)
        }
    }

    // What the item's content covers in its own coordinates.
    private func shape(
        of content: DisplayContent,
        frame: Rectangle
    ) -> ItemCoverage {
        switch content {
        case let .picture(picture):
            return ItemCoverage(pieces: [ConvexPolygon(rectangle: picture.destination)])

        case let .fill(fill):
            return ItemCoverage(
                pieces: [ConvexPolygon(rectangle: fill.rectangle)],
                holes: fill.hole.map { [ConvexPolygon(rectangle: $0.rectangle)] } ?? []
            )

        case let .stroke(stroke):
            // Centred on the rectangle's edge, so half its width lies to each side.
            let half = stroke.width / 2
            let inner = inset(stroke.rectangle, by: half)
            return ItemCoverage(
                pieces: [ConvexPolygon(rectangle: inset(stroke.rectangle, by: -half))],
                holes: inner.width > 0 && inner.height > 0 ? [ConvexPolygon(rectangle: inner)] : []
            )

        case let .arrow(arrow):
            return ItemCoverage(pieces: pieces(of: arrow))

        case let .glyphs(glyphs):
            let box = Rectangle(x: 0, y: 0, width: glyphs.size.width, height: glyphs.size.height)
            return ItemCoverage(pieces: [ConvexPolygon(rectangle: box)])

        case let .adjust(adjust):
            return ItemCoverage(pieces: [ConvexPolygon(rectangle: adjust.rectangle ?? frame)])
        }
    }

    // The shaft from the tail to the base of the head, and the head, which shrinks to the arrow's length on an arrow
    // shorter than it.
    private func pieces(of arrow: ArrowItem) -> [ConvexPolygon] {
        let dx = arrow.head.x - arrow.tail.x
        let dy = arrow.head.y - arrow.tail.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return [] }

        let along = Point(x: dx / length, y: dy / length)
        let across = Point(x: -along.y, y: along.x)
        let headLength = min(arrow.headSize, length)
        let base = Point(x: arrow.head.x - along.x * headLength, y: arrow.head.y - along.y * headLength)
        let point = { (origin: Point, distance: Double) in
            Point(x: origin.x + across.x * distance, y: origin.y + across.y * distance)
        }
        let shaft = ConvexPolygon(corners: [
            point(arrow.tail, arrow.width / 2),
            point(base, arrow.width / 2),
            point(base, -arrow.width / 2),
            point(arrow.tail, -arrow.width / 2)
        ])
        let head = ConvexPolygon(corners: [
            point(base, arrow.headSize / 2),
            arrow.head,
            point(base, -arrow.headSize / 2)
        ])

        return [shaft, head]
    }

    private func inset(
        _ rectangle: Rectangle,
        by distance: Double
    ) -> Rectangle {
        Rectangle(
            x: rectangle.x + distance,
            y: rectangle.y + distance,
            width: rectangle.width - 2 * distance,
            height: rectangle.height - 2 * distance
        )
    }

    // The transform that carries `rectangle` onto `other`.
    private func transform(
        from rectangle: Rectangle,
        onto other: Rectangle
    ) -> AffineTransform {
        guard rectangle.width != 0, rectangle.height != 0 else { return Self.collapsed }

        return AffineTransform(translation: Point(x: -rectangle.x, y: -rectangle.y))
            .concatenating(AffineTransform(
                mapping: Size(width: rectangle.width, height: rectangle.height),
                onto: other
            ))
    }
}
