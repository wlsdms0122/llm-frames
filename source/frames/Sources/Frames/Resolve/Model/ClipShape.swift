//
//  ClipShape.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a shape clip writes of its own, each value nil where not written; an `area` is the clip's. Keyframes are on the
// clip's clock, and lengths are theme lengths, not yet scaled. `radius`, `outset`, `fill`, `stroke` and `shadow` are
// as written, since they merge over the style before they are timed.
struct ClipShape: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let style: String?
    let width: PropertyValue<Double>?
    let height: PropertyValue<Double>?
    let points: PathProperty?
    let isClosed: Bool
    let radius: LookProperty?
    let outset: LookProperty?
    let fill: LookProperty?
    let stroke: LookProperty?
    let trim: PropertyValue<Trim>?
    let shadow: LookProperty?

    // A rect or an ellipse given by `width` and `height` is placed by its box, a path or a shape given by `area` by its
    // geometry. A rect missing one of the two is neither and stops when its geometry is planned.
    var isPlacedByBox: Bool { kind != .path && width != nil && height != nil }

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        style: String? = nil,
        width: PropertyValue<Double>? = nil,
        height: PropertyValue<Double>? = nil,
        points: PathProperty? = nil,
        isClosed: Bool = false,
        radius: LookProperty? = nil,
        outset: LookProperty? = nil,
        fill: LookProperty? = nil,
        stroke: LookProperty? = nil,
        trim: PropertyValue<Trim>? = nil,
        shadow: LookProperty? = nil
    ) {
        self.kind = kind
        self.style = style
        self.width = width
        self.height = height
        self.points = points
        self.isClosed = isClosed
        self.radius = radius
        self.outset = outset
        self.fill = fill
        self.stroke = stroke
        self.trim = trim
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}
