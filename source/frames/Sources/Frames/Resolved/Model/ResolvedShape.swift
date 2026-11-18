//
//  ResolvedShape.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape entry's own keys (FRAMES-19): its kind and geometry, each nil where the shape has none, `area` for a rect or
// ellipse placed by its area, `width` and `height` for one placed by its box, `points` and `isClosed` for a path, the
// geometry already grown by its outset, then `radius` and `trim` keyframes, and `fill`, `stroke` and `shadow` with
// its style applied and its lengths in output pixels. A shape placed by its geometry carries `position`, where its
// anchor point goes when the clip writes one, and `anchor`, the point of its geometry's box the clip names at its
// instant, fixed in its coordinate space, nil for the centre of that box at each time. Keyframes are in sequence time.
struct ResolvedShape: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let area: [Keyframe<Rectangle>]?
    let width: [Keyframe<Double>]?
    let height: [Keyframe<Double>]?
    let points: [Keyframe<[Point]>]?
    let isClosed: Bool?
    let radius: [Keyframe<Double>]
    let trim: [Keyframe<Trim>]
    let fill: Color?
    let stroke: PathStroke?
    let shadow: DropShadow?
    let position: [Keyframe<Point>]?
    let anchor: Point?

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        area: [Keyframe<Rectangle>]? = nil,
        width: [Keyframe<Double>]? = nil,
        height: [Keyframe<Double>]? = nil,
        points: [Keyframe<[Point]>]? = nil,
        isClosed: Bool? = nil,
        radius: [Keyframe<Double>],
        trim: [Keyframe<Trim>],
        fill: Color?,
        stroke: PathStroke?,
        shadow: DropShadow?,
        position: [Keyframe<Point>]? = nil,
        anchor: Point? = nil
    ) {
        self.kind = kind
        self.area = area
        self.width = width
        self.height = height
        self.points = points
        self.isClosed = isClosed
        self.radius = radius
        self.trim = trim
        self.fill = fill
        self.stroke = stroke
        self.shadow = shadow
        self.position = position
        self.anchor = anchor
    }

    // MARK: - Public
    // MARK: - Private
}
