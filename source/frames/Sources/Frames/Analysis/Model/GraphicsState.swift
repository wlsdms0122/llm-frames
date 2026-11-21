//
//  GraphicsState.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What holds an item as it is flattened: the map from the coordinates it is drawn in to output pixels, the clips that
// cut it in output pixels, the opacity of everything holding it, and the clip that drew what holds it, which an item
// without an origin of its own is named by. The map is `transform`, then each of `cornerPins` in order: `transform`
// carries the item to the coordinates of the innermost picture with a corner pin holding it, or to output pixels where
// none does, and each corner pin is the homography from its picture's destination to its corner pin followed by the
// transform that carries that picture's coordinates on, innermost first. A shape is cut to the part in front of each
// corner pin's horizon before that corner pin carries it.
struct GraphicsState: Equatable, Sendable {
    // MARK: - Property
    let transform: AffineTransform
    let cornerPins: [Homography]
    let clips: [ConvexPolygon]
    let opacity: Double
    let origin: ItemOrigin?

    // The whole map as one homography, in front of whose horizon lies everything the state carries.
    var map: Homography {
        cornerPins.reduce(Homography(transform)) { map, cornerPin in map.concatenating(cornerPin) }
    }

    // MARK: - Initializer
    init(
        transform: AffineTransform,
        cornerPins: [Homography] = [],
        clips: [ConvexPolygon],
        opacity: Double,
        origin: ItemOrigin?
    ) {
        self.transform = transform
        self.cornerPins = cornerPins
        self.clips = clips
        self.opacity = opacity
        self.origin = origin
    }

    // MARK: - Public
    // The state an item of the list drawn in this state is drawn in: its own coordinates, cut by the region its masks
    // bound, in the list's coordinates, and by its reveal, in its own.
    func holding(_ item: DisplayItem) -> GraphicsState {
        let held = GraphicsState(
            transform: item.transform.concatenating(transform),
            cornerPins: cornerPins,
            clips: clips,
            opacity: opacity * item.opacity,
            origin: item.origin ?? origin
        )
        let mask = ConvexPolygon(bounding: item.mask).map(carried)
        let reveal = item.reveal.map { held.carried(ConvexPolygon(rectangle: $0)) }

        return held.cut(by: [mask, reveal].compactMap { $0 })
    }

    // The state of a list nested in a picture drawn in this state: carried from the list onto the picture's
    // destination by `transform`, and cut by that destination and by the source rect it shows.
    func nesting(
        rectangle: Rectangle,
        transform: AffineTransform,
        destination: Rectangle
    ) -> GraphicsState {
        let nested = GraphicsState(
            transform: transform.concatenating(self.transform),
            cornerPins: cornerPins,
            clips: clips,
            opacity: opacity,
            origin: origin
        )

        return nested.cut(by: [
            carried(ConvexPolygon(rectangle: destination)),
            nested.carried(ConvexPolygon(rectangle: rectangle))
        ])
    }

    // The state of a list nested in a picture with a corner pin drawn in this state: carried from the list onto the
    // picture's destination by `transform`, then onto its corner pin by `cornerPin`. The whole list shows, the part
    // outside the source rect and the destination included (FRAMES-20).
    func nesting(
        transform: AffineTransform,
        cornerPin: Homography
    ) -> GraphicsState {
        GraphicsState(
            transform: transform,
            cornerPins: [cornerPin.concatenating(Homography(self.transform))] + cornerPins,
            clips: clips,
            opacity: opacity,
            origin: origin
        )
    }

    // The same state, cut by a rectangle in the coordinates it draws in.
    func clipped(to rectangle: Rectangle) -> GraphicsState {
        cut(by: [carried(ConvexPolygon(rectangle: rectangle))])
    }

    // A polygon in the coordinates the state draws in, carried to output pixels.
    func carried(_ polygon: ConvexPolygon) -> ConvexPolygon {
        cornerPins.reduce(polygon.applying(transform)) { polygon, cornerPin in polygon.carried(by: cornerPin) }
    }

    // What a shape drawn in this state covers of the output.
    func covered(_ shape: ItemCoverage) -> ItemCoverage {
        cut(ItemCoverage(pieces: shape.pieces.map(carried), holes: shape.holes.map(carried)))
    }

    // What a shape already in output pixels covers once cut by the clips.
    func cut(_ coverage: ItemCoverage) -> ItemCoverage {
        clips.reduce(coverage) { coverage, clip in coverage.clipped(to: clip) }
    }

    // MARK: - Private
    private func cut(by polygons: [ConvexPolygon]) -> GraphicsState {
        GraphicsState(
            transform: transform,
            cornerPins: cornerPins,
            clips: clips + polygons,
            opacity: opacity,
            origin: origin
        )
    }
}
