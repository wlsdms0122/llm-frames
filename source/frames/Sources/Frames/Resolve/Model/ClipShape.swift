//
//  ClipShape.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a shape clip writes of its own, each value nil where not written; an `area` is the clip's. Keyframes are on the
// clip's clock, and lengths are theme lengths, not yet scaled.
struct ClipShape: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let style: String?
    let width: PropertyValue<Double>?
    let height: PropertyValue<Double>?
    let points: PropertyValue<[PositionForm]>?
    let isClosed: Bool
    let radius: PropertyValue<Double>?
    let outset: Double?
    let fill: FillForm?
    let stroke: StrokeForm?
    let trim: PropertyValue<Trim>?
    let shadow: ShadowForm?

    // A rect or an ellipse given by `width` and `height` is placed by its box, a path or a shape given by `area` by its
    // geometry. A rect missing one of the two is neither and stops when its geometry is planned.
    var isPlacedByBox: Bool { kind != .path && width != nil && height != nil }

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        style: String? = nil,
        width: PropertyValue<Double>? = nil,
        height: PropertyValue<Double>? = nil,
        points: PropertyValue<[PositionForm]>? = nil,
        isClosed: Bool = false,
        radius: PropertyValue<Double>? = nil,
        outset: Double? = nil,
        fill: FillForm? = nil,
        stroke: StrokeForm? = nil,
        trim: PropertyValue<Trim>? = nil,
        shadow: ShadowForm? = nil
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
