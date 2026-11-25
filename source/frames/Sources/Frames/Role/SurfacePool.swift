//
//  SurfacePool.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import CoreVideo
import IOSurface
import os

// Surfaces of working values a role writes pictures into, each written again once no picture uses it, so its memory
// is not made and mapped anew for each picture. A surface taken is counted in use by its picture before the pool's
// lock is left, so no other taker writes it.
package final class SurfacePool: Sendable {
    // MARK: - Property
    private let surfaces = OSAllocatedUnfairLock<[IOSurfaceRef]>(uncheckedState: [])

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    // A surface of `width` by `height` RGBA half float pixels no picture uses, one made before where there is one, and
    // the picture that holds it. Nil where the system makes no surface of that size.
    package func surface(
        width: Int,
        height: Int
    ) -> (surface: IOSurfaceRef, picture: PictureSurface)? {
        surfaces.withLockUnchecked { surfaces in
            let free = surfaces.first {
                !IOSurfaceIsInUse($0) && IOSurfaceGetWidth($0) == width && IOSurfaceGetHeight($0) == height
            }
            if let free { return (free, PictureSurface(surface: free)) }

            let made = IOSurfaceCreate([
                kIOSurfaceWidth: width,
                kIOSurfaceHeight: height,
                kIOSurfaceBytesPerElement: 8,
                kIOSurfacePixelFormat: kCVPixelFormatType_64RGBAHalf
            ] as CFDictionary)
            guard let made else { return nil }
            surfaces.removeAll { !IOSurfaceIsInUse($0) }
            surfaces.append(made)

            return (made, PictureSurface(surface: made))
        }
    }

    // MARK: - Private
}
