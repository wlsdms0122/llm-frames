//
//  GeometryPlacement.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Where a shape placed by its geometry goes: `position`, where its anchor point goes when the clip writes one,
// keyframes in sequence time, and `anchor`, the point of its geometry's box as written, before `outset`, that the clip
// names, nil for the centre of that box at each time. Both are in the coordinates its geometry is written in.
struct GeometryPlacement: Equatable, Sendable {
    // MARK: - Property
    let position: [Keyframe<GeometryPoint>]?
    let anchor: GeometryAnchor?

    // MARK: - Initializer
    init(
        position: [Keyframe<GeometryPoint>]? = nil,
        anchor: GeometryAnchor? = nil
    ) {
        self.position = position
        self.anchor = anchor
    }

    // MARK: - Public
    // MARK: - Private
}
