//
//  MetalRenderer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/25/26.
//

import CoreImage
import Foundation
import Frames
import IOSurface

// The `metal` renderer: composites display lists on the GPU with Core Image on the working values of FRAMES-26, each
// list in the form its `compositing` names (`LayerCompositor`), and draws what it has no GPU operation for with the
// Core Graphics drawing of `quartz`, a list given as sample lists whole. It accepts the lists `quartz` accepts, by the
// same check. A frame is a surface of the list's size, rendered once and finished before it is handed over.
package final class MetalRenderer: Sendable {
    // MARK: - Property
    private let pictures: MediaPictureCache
    private let tables = LookUpTableCache()
    private let fonts = FontLibrary()
    private let surfaces = SurfacePool()

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.pictures = MediaPictureCache(decoder: decoder)
    }

    // MARK: - Public
    // MARK: - Private
    // Renders `bounds` of the image into the surface as encoded working values, unclamped and undithered, and waits
    // until the surface is written.
    private func render(
        _ image: CIImage,
        in bounds: CGRect,
        compositing: Compositing,
        to surface: IOSurfaceRef
    ) throws {
        let destination = CIRenderDestination(ioSurface: surface)
        destination.colorSpace = WorkingSpace.encoded
        destination.alphaMode = .premultiplied
        destination.isClamped = false
        destination.isDithered = false
        let task = try WorkingSpace.context(of: compositing)
            .startTask(toRender: image, from: bounds, to: destination, at: .zero)
        _ = try task.waitUntilCompleted()
    }

    // Copies a half float bitmap of the surface's size into it, row by row.
    private func copy(
        _ bitmap: Bitmap,
        to surface: IOSurfaceRef
    ) {
        IOSurfaceLock(surface, [], nil)
        defer { IOSurfaceUnlock(surface, [], nil) }

        let base = IOSurfaceGetBaseAddress(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        let rowLength = bitmap.width * 8
        bitmap.pixels.withUnsafeBytes { pixels in
            for row in 0..<bitmap.height {
                (base + row * bytesPerRow)
                    .copyMemory(from: pixels.baseAddress! + row * bitmap.bytesPerRow, byteCount: rowLength)
            }
        }
    }
}

extension MetalRenderer: Renderer {
    // MARK: - Lifecycle
    package func check(_ list: DisplayList) throws {
        try DisplayListChecker(tables: tables).check(list)
    }

    package func frame(of list: DisplayList) throws -> Pixels {
        try autoreleasepool {
            let raster = Raster(holding: list.size)
            guard let (surface, picture) = surfaces.surface(width: raster.width, height: raster.height) else {
                throw QuartzError.unmadeBitmap(width: raster.width, height: raster.height)
            }

            let drawer = FrameDrawer(pictures: pictures, tables: tables, fonts: fonts)
            switch list.content {
            case let .items(items):
                let compositor = LayerCompositor(drawer: drawer, pictures: pictures)
                let image = try compositor.image(of: items, in: list)
                try render(image, in: raster.bounds, compositing: list.compositing, to: surface)
                withExtendedLifetime(compositor) { }

            case .samples:
                copy(try drawer.draw(list).bitmap(), to: surface)
            }

            return .surface(picture)
        }
    }
}
