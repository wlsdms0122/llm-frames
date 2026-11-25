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
// by source-over, or by its blend mode's kernel (`Blender`), and every layer made on the GPU is left unrendered until
// the frame is rendered. A picture of a media frame with no transition matte, corner pin, mask, track matte or reveal,
// at any scale, turn and position, is a layer made on the GPU from the decoder's pixels: resampled by
// `PictureResampler`, the resampling of `quartz`, and covered as `PictureDrawer` covers it, by the resampler at square
// corners and by the coverage Core Graphics gives the destination with its corners rounded otherwise, or, filtered,
// the Core Image image `PictureDrawer` filters it into. Its border is drawn by `PictureDrawer` into a layer of the part
// of the raster it covers, its shadow cast from the picture and the border as `FrameDrawer` casts one, and the whole
// is scaled by its opacity. An adjustment with no reveal is the image below it through its filter, times the coverage
// `FrameDrawer` gives its masks and track matte and its opacity. Every other item is drawn by `FrameDrawer` into a
// layer of the part of the raster it covers. The items of a nested list drawn in place are laid one by one, as
// `FrameDrawer` draws them.
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
        if let picture = try picture(of: item, in: list, seed: seed, on: raster) {
            return picture.cropped(to: raster.bounds)
        }
        if let adjusted = try adjusted(item, in: list, seed: seed, over: frame, on: raster) { return adjusted }

        let area = drawer.area(of: item, in: list)
        guard !area.isEmpty else { return nil }

        let layer = try drawer.layer(of: item, in: list, seed: seed, area: area, over: { frame })

        return CIImage(cgImage: try layer.image())
            .transformed(by: CGAffineTransform(translationX: area.minX, y: CGFloat(raster.height) - area.maxY))
    }

    // The picture item's media resampled onto the raster on the GPU, filtered and covered, under its border and over
    // its shadow, and scaled by its opacity, nil where the item is not one the GPU draws this way. `seed` is that of
    // the list the item was written in.
    private func picture(
        of item: DisplayItem,
        in list: DisplayList,
        seed: Int,
        on raster: Raster
    ) throws -> CIImage? {
        guard
            case let .picture(picture) = item.content,
            item.mask.isEmpty,
            item.trackMatte == nil,
            item.reveal == nil,
            picture.drawsSourceAlone,
            case let .media(frame) = picture.source,
            frame.picture != .page
        else {
            return nil
        }

        let source = try pictures.source(of: frame)
        guard let placement = picture.placement(ofSourceSized: source.size) else { return nil }

        read.append(try pictures.pixels(of: frame))
        // Core Image counts rows from the bottom, of the source and of the raster.
        let height = CGFloat(raster.height)
        let sourceFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: source.size.height)
        let rasterFlip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        let matrix = CGAffineTransform(item.transform).concatenating(raster.transform)
        let device = matrix.concatenating(rasterFlip)
        let map = sourceFlip.concatenating(placement).concatenating(device)
        // A picture that casts a shadow is drawn as far past the raster as the shadow reaches into it from.
        let margin = picture.shadow
            .map { CGFloat(CastShadow($0, through: matrix, rasterScale: raster.transform.lengthScale).margin) } ?? 0
        let bounds = raster.bounds.insetBy(dx: -margin, dy: -margin)
        var image: CIImage
        if !picture.filter.isEmpty {
            image = try PictureDrawer(chain: drawer.chain).filtered(
                picture,
                source: source,
                matte: nil,
                seed: seed,
                through: device,
                within: bounds,
                compositing: list.compositing
            )
        } else if picture.radius == 0 {
            guard let shown = picture.shownSource(ofSourceSized: source.size) else { return CIImage.empty() }

            image = try PictureResampler()
                .resample(source.picture, through: map, covering: shown.applying(sourceFlip), within: bounds)
        } else {
            let outline = PathOutline(.rect(picture.destination, radius: picture.radius)).path
            let area = outline.boundingBoxOfPath.applying(matrix).integral.intersection(bounds)
            guard !area.isNull, !area.isEmpty else { return CIImage.empty() }

            let extended = picture.extendedSource(ofSourceSized: source.size)
            let resampled = try PictureResampler().resample(
                source.picture,
                through: map,
                covering: extended.applying(sourceFlip),
                within: area.applying(rasterFlip)
            )
            let coverage = try layer(over: area, of: raster, compositing: list.compositing) { context in
                context.concatenate(matrix)
                context.addPath(outline)
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.fillPath()
            }
            image = resampled
                .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: coverage])
        }

        if picture.border != nil {
            let drawn = CGRect(picture.drawnBounds(carriedBy: item.transform)).applying(matrix)
            let area = drawn.integral.insetBy(dx: -1, dy: -1).intersection(bounds)
            let border = try layer(over: area, of: raster, compositing: list.compositing) { context in
                context.concatenate(matrix)
                PictureDrawer.border(of: picture, carriedBy: item.transform, in: context)
            }
            image = border.composited(over: image)
        }

        if let shadow = picture.shadow {
            image = image.composited(over: cast(shadow, from: image, through: matrix, on: raster))
        }

        return scaled(image, by: item.opacity)
    }

    // The adjustment's layer: `frame`, the image below it, through its filter, times the coverage of its masks and
    // track matte and its opacity, nil where the item is not an adjustment or has a reveal. `seed` is that of the list
    // the item was written in.
    private func adjusted(
        _ item: DisplayItem,
        in list: DisplayList,
        seed: Int,
        over frame: CIImage,
        on raster: Raster
    ) throws -> CIImage? {
        guard case let .adjust(adjust) = item.content, item.reveal == nil else { return nil }

        // The item's transform carries only its reveal, and one that flattens the plane leaves nothing drawn.
        let matrix = CGAffineTransform(item.transform).concatenating(raster.transform)
        guard matrix.a * matrix.d - matrix.b * matrix.c != 0 else { return CIImage.empty() }

        var image = try drawer.filtered(frame, by: adjust, on: raster, seed: seed, compositing: list.compositing)
        if let coverage = try drawer.coverage(of: item, over: raster.bounds, on: raster) {
            // The coverage's grey values are taken as they are, outside colour management, as a clip takes them.
            let values = CIImage(cgImage: coverage, options: [.colorSpace: NSNull()])
            image = image.applyingFilter(
                "CIBlendWithRedMask",
                parameters: [
                    kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: image.extent),
                    kCIInputMaskImageKey: values
                ]
            )
        }

        return scaled(image, by: item.opacity)
    }

    // The image times `opacity`.
    private func scaled(
        _ image: CIImage,
        by opacity: Double
    ) -> CIImage {
        guard opacity < 1 else { return image }

        let alpha = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: opacity)).cropped(to: image.extent)

        return image.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: alpha])
    }

    // The shadow `picture` casts, an image of the raster: its alpha in the shadow's colour, blurred and moved, worked
    // out in the coordinates of the layer `FrameDrawer` casts a shadow from, a margin wider than the raster on every
    // side, so Core Image blurs it on the same grid.
    private func cast(
        _ shadow: DropShadow,
        from picture: CIImage,
        through matrix: CGAffineTransform,
        on raster: Raster
    ) -> CIImage {
        let cast = CastShadow(shadow, through: matrix, rasterScale: raster.transform.lengthScale)
        let margin = CGFloat(cast.margin)
        let layer = CGRect(origin: .zero, size: CGSize(width: raster.width, height: raster.height))
            .insetBy(dx: -margin, dy: -margin)
            .offsetBy(dx: margin, dy: margin)
        let shifted = picture.transformed(by: CGAffineTransform(translationX: margin, y: margin))
        var tinted = CIImage(color: CIColor(cgColor: cast.color.cgColor))
            .cropped(to: layer)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: shifted])
        if cast.blur > 0 {
            tinted = tinted.applyingGaussianBlur(sigma: cast.blur)
        }

        // Core Image counts rows from the bottom, so a shadow moved down moves to a smaller y.
        return tinted
            .transformed(
                by: CGAffineTransform(translationX: cast.offset.width - margin, y: -cast.offset.height - margin)
            )
            .cropped(to: raster.bounds)
    }

    // What `drawing` draws in the raster's pixels over `area`, whole pixels of the raster, as an image of the raster
    // placed at the area, drawn by Core Graphics in the form `compositing` names.
    private func layer(
        over area: CGRect,
        of raster: Raster,
        compositing: Compositing,
        drawing: (CGContext) throws -> Void
    ) throws -> CIImage {
        guard !area.isEmpty else { return CIImage.empty() }

        let layer = try FrameContext(width: Int(area.width), height: Int(area.height), compositing: compositing)
        layer.context.translateBy(x: -area.minX, y: -area.minY)
        try drawing(layer.context)

        return CIImage(cgImage: try layer.image())
            .transformed(by: CGAffineTransform(translationX: area.minX, y: CGFloat(raster.height) - area.maxY))
    }
}
