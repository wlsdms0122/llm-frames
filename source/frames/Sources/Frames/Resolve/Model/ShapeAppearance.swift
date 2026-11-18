//
//  ShapeAppearance.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape clip is drawn once its style is applied, its lengths in output pixels and keyframes in sequence time:
// `width` and `height` size a rect's or an ellipse's box, already grown by `outset`, nil for a shape placed by its
// geometry, whose area is grown by `outset` where it is written. `anchor` is the anchor point named on a shape placed
// by its geometry, nil for the centre of its geometry's box. `radius` is 0 and `trim` `[0, 1]` when neither is written.
struct ShapeAppearance: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let width: PropertyValue<Double>?
    let height: PropertyValue<Double>?
    let isClosed: Bool
    let outset: Double
    let anchor: String?
    let radius: PropertyValue<Double>
    let trim: PropertyValue<Trim>
    let fill: Color?
    let stroke: PathStroke?
    let shadow: DropShadow?

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        width: PropertyValue<Double>?,
        height: PropertyValue<Double>?,
        isClosed: Bool,
        outset: Double,
        anchor: String?,
        radius: PropertyValue<Double>,
        trim: PropertyValue<Trim>,
        fill: Color?,
        stroke: PathStroke?,
        shadow: DropShadow?
    ) {
        self.kind = kind
        self.width = width
        self.height = height
        self.isClosed = isClosed
        self.outset = outset
        self.anchor = anchor
        self.radius = radius
        self.trim = trim
        self.fill = fill
        self.stroke = stroke
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}
