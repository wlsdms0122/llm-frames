//
//  ResolvedShape.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape entry's own keys: its kind and how it is placed, its geometry as the clip wrote it and its `outset` in output
// pixels, then `trim` keyframes, and `radius`, `fill`, `stroke` and `shadow` as timed values with its style applied
// and its lengths in output pixels, `off` where it has none. Keyframes are in sequence time.
struct ResolvedShape: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let geometry: ShapeGeometry
    let radius: TimedValue
    let trim: [Keyframe<Trim>]
    let fill: TimedValue
    let stroke: TimedValue
    let shadow: TimedValue

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        geometry: ShapeGeometry,
        radius: TimedValue,
        trim: [Keyframe<Trim>],
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
