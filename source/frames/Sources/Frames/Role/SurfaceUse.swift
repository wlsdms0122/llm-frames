//
//  SurfaceUse.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import IOSurface

// One holder's use of a surface, counted in the surface's use count from when it is made to when the last copy of
// the picture that holds it goes, so whoever made the surface writes it again only once `IOSurfaceIsInUse` is false.
final class SurfaceUse: @unchecked Sendable {
    // MARK: - Property
    let surface: IOSurfaceRef

    // MARK: - Initializer
    init(surface: IOSurfaceRef) {
        self.surface = surface
        IOSurfaceIncrementUseCount(surface)
    }

    deinit {
        IOSurfaceDecrementUseCount(surface)
    }

    // MARK: - Public
    // MARK: - Private
}
