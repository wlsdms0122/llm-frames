//
//  ResolvedShape.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape entry's own keys (FRAMES-19): its kind and how it is placed, its geometry as the clip wrote it and its
// `outset` in output pixels, then `radius` and `trim` keyframes, and `fill`, `stroke` and `shadow` with its style
// applied and its lengths in output pixels. Keyframes are in sequence time.
struct ResolvedShape: Equatable, Sendable {
    // MARK: - Property
    let kind: ShapeKind
    let geometry: ShapeGeometry
    let radius: [Keyframe<Double>]
    let trim: [Keyframe<Trim>]
    let fill: Color?
    let stroke: PathStroke?
    let shadow: DropShadow?

    // MARK: - Initializer
    init(
        kind: ShapeKind,
        geometry: ShapeGeometry,
        radius: [Keyframe<Double>],
        trim: [Keyframe<Trim>],
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
