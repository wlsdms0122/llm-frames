//
//  LayerCompositor.swift
//  FramesQuartz
//
//  Created by JSilver on 11/25/26.
//

import CoreGraphics
import CoreImage
import Frames

// Composites the items of one frame's list on the GPU, bottom first, as a Core Image image of the list's raster, rows
// counted from the bottom, in the form the list's `compositing` names. Each item is a layer laid over what is below it
// by source-over, or by its blend mode's kernel (`Blender`). A picture that shows its media source alone, with no mask,
// track matte or reveal, at any scale, turn and position, is a layer made on the GPU from the decoder's pixels,
// resampled and covered by `PictureResampler`, the resampling of `quartz`, with its opacity. Every other item is drawn
// by `FrameDrawer` into a layer of the part of the raster it covers, an adjustment reading the image below it. The
// items of a nested list drawn in place are laid one by one, as `FrameDrawer` draws them.
final class LayerCompositor {
    // MARK: - Property
    private let drawer: FrameDrawer
    private let pictures: MediaPictureCache

    // The pictures the layers read, held until the frame is rendered.
    private var read: [Pixels] = []

    // MARK: - Initializer
    init(
        drawer: FrameDrawer,
        pictures: MediaPictureCache
    ) {
        self.drawer = drawer
        self.pictures = pictures
    }

    // MARK: - Public
    // The frame of the list's items over its background, its extent the raster's bounds.
    func image(
        of items: [DisplayItem],
        in list: DisplayList
    ) throws -> CIImage {
        let raster = Raster(holding: list.size)
        var frame = CIImage(color: CIColor(cgColor: list.background.cgColor)).cropped(to: raster.bounds)
        try lay(items, seed: list.seed, of: list, place: "items", over: &frame)

        return frame
    }

    // MARK: - Private
    // `seed` is that of the list the items were written in, and `place` is their path in the list.
    private func lay(
        _ items: [DisplayItem],
        seed: Int,
        of list: DisplayList,
        place: String,
        over frame: inout CIImage
    ) throws {
        for (index, item) in items.enumerated() {
            guard let mode = BlendMode(rawValue: item.blend) else {
                throw QuartzError.unsupportedBlend(name: item.blend, place: "\(place)[\(index)].blend")
            }
            guard item.opacity > 0 else { continue }

            if let inner = drawer.listDrawnInPlace(by: item, of: list), case let .items(innerItems) = inner.content {
                try lay(innerItems, seed: inner.seed, of: list, place: "items", over: &frame)
                continue
            }

            guard let layer = try layer(of: item, in: list, seed: seed, over: frame) else { continue }

            frame = mode == .normal
                ? layer.composited(over: frame)
                : try Blender().composite(layer, over: frame, mode: mode, compositing: list.compositing)
        }
    }

    // The item's layer within the raster's bounds, nil where it covers none of the raster.
    private func layer(
        of item: DisplayItem,
        in list: DisplayList,
        seed: Int,
        over frame: CIImage
    ) throws -> CIImage? {
        let raster = Raster(holding: list.size)
        if let picture = try picture(of: item, on: raster) { return picture.cropped(to: raster.bounds) }

        let area = drawer.area(of: item, in: list)
        guard !area.isEmpty else { return nil }

        let layer = try drawer.layer(of: item, in: list, seed: seed, area: area, over: { frame })

        return CIImage(cgImage: try layer.image())
            .transformed(by: CGAffineTransform(translationX: area.minX, y: CGFloat(raster.height) - area.maxY))
    }

    // The picture item's media resampled onto the raster on the GPU, covered where it shows its source and scaled by
    // its opacity, nil where the item is not one the GPU draws this way.
    private func picture(
        of item: DisplayItem,
        on raster: Raster
    ) throws -> CIImage? {
        guard
            case let .picture(picture) = item.content,
            item.mask.isEmpty,
            item.trackMatte == nil,
            item.reveal == nil,
            picture.showsSourceAlone,
            case let .media(frame) = picture.source,
            frame.picture != .page
        else {
            return nil
        }

        let pixels = try pictures.pixels(of: frame)
        let size = CGSize(width: pixels.width, height: pixels.height)
        guard let placement = picture.placement(ofSourceSized: size) else { return nil }

        read.append(pixels)
        let source = switch pixels {
        case let .surface(surface):
            CIImage(ioSurface: surface.surface, options: [.colorSpace: WorkingSpace.encoded])

        case .bitmap:
            CIImage(cgImage: try pictures.image(of: frame))
        }

        // Core Image counts rows from the bottom, of the source and of the raster.
        let height = CGFloat(raster.height)
        let sourceFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
        let map = sourceFlip
            .concatenating(placement)
            .concatenating(CGAffineTransform(item.transform))
            .concatenating(raster.transform)
            .concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height))
        guard let shown = picture.shownSource(ofSourceSized: size) else { return CIImage.empty() }

        let image = try PictureResampler()
            .resample(source, through: map, covering: shown.applying(sourceFlip), within: raster.bounds)
        guard item.opacity < 1 else { return image }

        let opacity = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: item.opacity)).cropped(to: image.extent)

        return image.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: opacity])
    }
}
