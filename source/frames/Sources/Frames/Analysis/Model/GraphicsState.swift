//
//  GraphicsState.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What holds an item as it is flattened: the transform from the coordinates it is drawn in to output pixels, the clips
// that cut it in output pixels, the opacity of everything holding it, and the clip that drew what holds it, which an
// item without an origin of its own is named by.
struct GraphicsState: Equatable, Sendable {
    // MARK: - Property
    let transform: AffineTransform
    let clips: [ConvexPolygon]
    let opacity: Double
    let origin: ItemOrigin?

    // MARK: - Initializer
    init(
        transform: AffineTransform,
        clips: [ConvexPolygon],
        opacity: Double,
        origin: ItemOrigin?
    ) {
        self.transform = transform
        self.clips = clips
        self.opacity = opacity
        self.origin = origin
    }

    // MARK: - Public
    // The state an item of the list drawn in this state is drawn in: its own coordinates, cut by its mask, in the
    // list's coordinates, and by its reveal, in its own.
    func holding(_ item: DisplayItem) -> GraphicsState {
        let transform = item.transform.concatenating(self.transform)
        let mask = item.mask.map { ConvexPolygon(rectangle: $0, transform: self.transform) }
        let reveal = item.reveal.map { ConvexPolygon(rectangle: $0, transform: transform) }

        return GraphicsState(
            transform: transform,
            clips: clips + [mask, reveal].compactMap { $0 },
            opacity: opacity * item.opacity,
            origin: item.origin ?? origin
        )
    }

    // The state of a list nested in a picture drawn in this state: carried from the list onto the picture's
    // destination by `transform`, and cut by that destination and by the source rect it shows.
    func nesting(
        rectangle: Rectangle,
        transform: AffineTransform,
        destination: Rectangle
    ) -> GraphicsState {
        let nested = transform.concatenating(self.transform)

        return GraphicsState(
            transform: nested,
            clips: clips + [
                ConvexPolygon(rectangle: destination, transform: self.transform),
                ConvexPolygon(rectangle: rectangle, transform: nested)
            ],
            opacity: opacity,
            origin: origin
        )
    }

    // The same state, cut by a rectangle in the coordinates it draws in.
    func clipped(to rectangle: Rectangle) -> GraphicsState {
        GraphicsState(
            transform: transform,
            clips: clips + [ConvexPolygon(rectangle: rectangle, transform: transform)],
            opacity: opacity,
            origin: origin
        )
    }

    // What a shape drawn in this state covers of the output.
    func covered(_ shape: ItemCoverage) -> ItemCoverage {
        clips.reduce(shape.applying(transform)) { coverage, clip in coverage.clipped(to: clip) }
    }

    // MARK: - Private
}
