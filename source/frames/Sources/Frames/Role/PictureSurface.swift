//
//  PictureSurface.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import IOSurface

// An IOSurface of working values in the layout of a `Bitmap` of depth `halfFloat`: RGBA half floats with premultiplied
// alpha, extended-range sRGB encoded, rows top first and `bytesPerRow` apart, in the machine's byte order. Whoever
// made it has finished writing it before it is handed over, and nothing writes it while a picture holds it, which the
// surface's use count says, so it is read from any thread.
package struct PictureSurface: Sendable {
    // MARK: - Property
    private let use: SurfaceUse

    package var surface: IOSurfaceRef {
        use.surface
    }

    package var width: Int {
        IOSurfaceGetWidth(surface)
    }

    package var height: Int {
        IOSurfaceGetHeight(surface)
    }

    package var bytesPerRow: Int {
        IOSurfaceGetBytesPerRow(surface)
    }

    // The surface's memory as a bitmap, locked for reading while the bitmap's pixels live.
    package var bitmap: Bitmap {
        let use = use
        let count = bytesPerRow * height
        IOSurfaceLock(use.surface, .readOnly, nil)
        let pixels = Data(
            bytesNoCopy: IOSurfaceGetBaseAddress(use.surface),
            count: count,
            deallocator: .custom { _, _ in IOSurfaceUnlock(use.surface, .readOnly, nil) }
        )

        return Bitmap(width: width, height: height, depth: .halfFloat, bytesPerRow: bytesPerRow, pixels: pixels)
    }

    // MARK: - Initializer
    // `surface` counted in use from here until the picture goes.
    package init(surface: IOSurfaceRef) {
        self.use = SurfaceUse(surface: surface)
    }

    // MARK: - Public
    // MARK: - Private
}
