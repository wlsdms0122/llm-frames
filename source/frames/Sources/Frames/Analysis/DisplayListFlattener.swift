//
//  DisplayListFlattener.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Flattens a display list into its items, bottom first, each with the map from its own coordinates to output pixels,
// its extent in them, and what it covers of the output frame. A picture of a nested list is replaced by that list's
// background and items, carried through the picture's source rect, destination and transform and cut by its mask,
// reveal and destination, so they cover only what the picture shows. What an item covers follows its shape in convex
// pieces: a picture's destination, a path's geometry with its stroke and arrowheads, a glyphs item's box (a unit's item cut to its unit's box by its reveal), and an
// adjustment's list frame, each cut to the region its masks bound (`ConvexPolygon(bounding:)`). Rounded corners,
// transition mattes and track mattes are left out: a track matte's source is not drawn as items of the list, and does
// not cut what its item covers.
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
        let background = list.background.isTransparent
            ? []
            : [FlattenedItem(
                origin: state.origin,
                item: .background,
                opacity: state.opacity,
                transform: state.transform,
                rect: frame,
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
        let transform: AffineTransform
        let rect: Rectangle
        let coverage: ItemCoverage
        switch item.content {
        case let .picture(picture):
            return items(of: picture, own: own)

        case let .path(path):
            transform = own.transform
            rect = box(of: path.geometry)
            coverage = own.covered(ItemCoverage(path: path, carriedBy: item.transform))

        case let .glyphs(glyphs):
            // A title's background drawn alone, under its units, covers only its rect, or nothing without one, and a
            // unit's item its unit's box.
            let box = glyphs.runs.isEmpty && glyphs.layer == nil
                ? glyphs.background?.rectangle
                : glyphs.unitBox ?? Rectangle(x: 0, y: 0, width: glyphs.size.width, height: glyphs.size.height)
            guard let box else { return [] }

            transform = own.transform
            rect = extent(of: glyphs)
            coverage = own.covered(ItemCoverage(pieces: [ConvexPolygon(rectangle: box)]))

        case .adjust:
            // An adjustment covers its list's frame, which its own transform does not carry.
            transform = state.transform
            rect = frame
            coverage = own.cut(ItemCoverage(pieces: [ConvexPolygon(rectangle: frame, transform: state.transform)]))
        }

        return [FlattenedItem(
            origin: own.origin,
            item: ItemKind(content: item.content),
            opacity: own.opacity,
            transform: transform,
            rect: rect,
            coverage: coverage
        )]
    }

    private func items(
        of picture: PictureItem,
        own: GraphicsState
    ) -> [FlattenedItem] {
        switch picture.source {
        case let .media(media):
            // Without a source rect the picture shows the whole frame, whose size in pixels is not known here.
            let transform = picture.rectangle.flatMap { rectangle in
                own.transform.inverse.map { $0.concatenating(transform(from: picture.destination, onto: rectangle)) }
            }
            let placement = MediaPlacement(frame: media, transform: transform)
            let coverage = own.covered(ItemCoverage(pieces: [ConvexPolygon(rectangle: picture.destination)]))
            return [FlattenedItem(
                origin: own.origin,
                item: .picture,
                opacity: own.opacity,
                transform: own.transform,
                rect: picture.destination,
                coverage: coverage,
                media: placement
            )]

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

    // The box of a path's geometry as the list gives it, without its stroke.
    private func box(of geometry: PathGeometry) -> Rectangle {
        switch geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            rectangle

        case let .polyline(points, _):
            Rectangle(bounding: points)
        }
    }

    // The extent of a glyphs item in its own coordinates: a unit's glyph box for a unit's item, and the whole text box
    // otherwise.
    private func extent(of glyphs: GlyphsItem) -> Rectangle {
        glyphs.unitGlyphBox ?? glyphs.textBox
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
