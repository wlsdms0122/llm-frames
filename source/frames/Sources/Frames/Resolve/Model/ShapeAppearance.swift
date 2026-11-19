//
//  ShapeAppearance.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape clip is drawn once its style is applied, its lengths in output pixels and keyframes in sequence time,
// and how it is placed. `radius`, `fill`, `stroke` and `shadow` are timed values, `off` where the shape has none, and
// `trim` is `[0, 1]` when not written.
struct ShapeAppearance: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let geometry: ShapeGeometryPlan
    let radius: TimedValue
    let trim: PropertyValue<Trim>
    let fill: TimedValue
    let stroke: TimedValue
    let shadow: TimedValue

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        geometry: ShapeGeometryPlan,
        radius: TimedValue,
        trim: PropertyValue<Trim>,
        fill: TimedValue,
        stroke: TimedValue,
        shadow: TimedValue
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
