//
//  MaskSample.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// One mask of a clip at one time: its geometry in the clip's own coordinate space, a path mask a closed polyline, its
// feather in output pixels, whether it is inverted, and how it combines with the masks before it.
struct MaskSample: Equatable, Sendable {
    // MARK: - Property
    let geometry: PathGeometry
    let feather: Double
    let isInverted: Bool
    let mode: MaskMode

    // MARK: - Initializer
    init(
        geometry: PathGeometry,
        feather: Double,
        isInverted: Bool,
        mode: MaskMode
    ) {
        self.geometry = geometry
        self.feather = feather
        self.isInverted = isInverted
        self.mode = mode
    }

    // MARK: - Public
    // MARK: - Private
}
