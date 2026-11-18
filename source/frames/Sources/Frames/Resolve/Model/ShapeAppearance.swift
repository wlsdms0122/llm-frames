//
//  ShapeAppearance.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape clip is drawn once its style is applied, its lengths in output pixels and keyframes in sequence time,
// and how it is placed. `radius` is 0 and `trim` `[0, 1]` when neither is written.
struct ShapeAppearance: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let geometry: ShapeGeometryPlan
    let radius: PropertyValue<Double>
    let trim: PropertyValue<Trim>
    let fill: Color?
    let stroke: PathStroke?
    let shadow: DropShadow?

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        geometry: ShapeGeometryPlan,
        radius: PropertyValue<Double>,
        trim: PropertyValue<Trim>,
        fill: Color?,
        stroke: PathStroke?,
        shadow: DropShadow?
    ) {
        self.kind = kind
        self.geometry = geometry
        self.radius = radius
        self.trim = trim
        self.fill = fill
        self.stroke = stroke
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}
