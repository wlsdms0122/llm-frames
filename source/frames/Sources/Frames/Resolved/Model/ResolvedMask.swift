//
//  ResolvedMask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// One mask of a clip at a keyframe: its geometry in the clip's own coordinate space, a path mask a closed polyline and
// a box mask its rect, its feather in output pixels, whether it is inverted, and how it combines with the masks before
// it. Between keyframes the geometry interpolates per component and the feather as a number. Resolve stops on
// keyframes whose masks differ in shape, geometry form, number of points, inversion or mode, so those are the same at
// both ends.
struct ResolvedMask: Interpolable {
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
    static func interpolate(
        from start: ResolvedMask,
        to end: ResolvedMask,
        progress: Double
    ) -> ResolvedMask {
        ResolvedMask(
            geometry: .interpolate(from: start.geometry, to: end.geometry, progress: progress),
            feather: .interpolate(from: start.feather, to: end.feather, progress: progress),
            isInverted: start.isInverted,
            mode: start.mode
        )
    }

    // The same mask with its geometry in another space; its feather, inversion and mode go with it.
    func replacing(geometry: PathGeometry) -> ResolvedMask {
        ResolvedMask(geometry: geometry, feather: feather, isInverted: isInverted, mode: mode)
    }

    // MARK: - Private
}
