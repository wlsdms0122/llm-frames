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
// is not made and mapped anew for each picture. Each surface is made with an `Attachment`, what its taker writes it
// through, such as a GPU texture on it, kept as long as the surface, so it is not made anew either. A surface taken is
// counted in use by its picture before the pool's lock is left, so no other taker writes it or uses its attachment, and
// an attachment is used only by the one taker of its surface, on that taker's thread.
package final class SurfacePool<Attachment>: @unchecked Sendable {
    // MARK: - Property
    private let entries = OSAllocatedUnfairLock<[(surface: IOSurfaceRef, attachment: Attachment)]>(uncheckedState: [])
    // The attachment of a surface just made, nil where it cannot be made for it.
    private let attach: @Sendable (IOSurfaceRef) -> Attachment?

    // MARK: - Initializer
    package init(attach: @escaping @Sendable (IOSurfaceRef) -> Attachment?) {
        self.attach = attach
    }

    // MARK: - Public
    // A surface of `width` by `height` RGBA half float pixels no picture uses, one made before where there is one, with
    // its attachment and the picture that holds it. Nil where the system makes no surface of that size or no attachment
    // for it.
    package func surface(
        width: Int,
        height: Int
    ) -> (surface: IOSurfaceRef, attachment: Attachment, picture: PictureSurface)? {
        entries.withLockUnchecked { entries in
            let free = entries.first {
                !IOSurfaceIsInUse($0.surface)
                    && IOSurfaceGetWidth($0.surface) == width
                    && IOSurfaceGetHeight($0.surface) == height
            }
            if let free { return (free.surface, free.attachment, PictureSurface(surface: free.surface)) }

            let made = IOSurfaceCreate([
                kIOSurfaceWidth: width,
                kIOSurfaceHeight: height,
                kIOSurfaceBytesPerElement: 8,
                kIOSurfacePixelFormat: kCVPixelFormatType_64RGBAHalf
            ] as CFDictionary)
            guard let made, let attachment = attach(made) else { return nil }
            entries.removeAll { !IOSurfaceIsInUse($0.surface) }
            entries.append((made, attachment))

            return (made, attachment, PictureSurface(surface: made))
        }
    }

    // MARK: - Private
}

extension SurfacePool where Attachment == Void {
    // A pool whose surfaces carry nothing more, for a taker that writes each surface through what it makes for it.
    package convenience init() {
        self.init { _ in () }
    }
}
