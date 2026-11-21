//
//  FrameDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Frames

// Draws the display lists of one output frame, items bottom first. An item's masks and track matte multiply its alpha
// in output pixels, and an item with a shadow casts it from that masked picture, so they do not cut the shadow.
// Opacity below 1 and the blend mode apply to the item and its shadow as a whole. A nested list, a track matte's
// source among them, is drawn on a raster at the scale it is shown at, once per frame for each raster, so it is as
// sharp as its items drawn in place; every length in pixels inside it is scaled with it. A page of a PDF is read from
// the decoder at the scale its raster shows it at, so it is as sharp as its paths drawn there. Each list is drawn in
// the form of the working values its `compositing` names, which its items are composited, covered, resampled, blurred
// and mixed in, and its picture is converted to the form of the list that shows it. The frame is a half float bitmap
// of encoded working values.
final class FrameDrawer {
    // MARK: - Property
    private let pictures: MediaPictureCache
    private let tables: LookUpTableCache
    private let glyphDrawer: GlyphDrawer

    // A page's whole picture is read where it holds at most this many pixels, a 4096 by 4096 square.
    private static let wholePagePixels = 1 << 24
    // How far past a pixel, in the raster's pixels, a transition matte's resampling reads its picture.
    private static let matteResamplingReach: CGFloat = 3

    private var nested: [(list: DisplayList, raster: Raster, image: CGImage)] = []

    // MARK: - Initializer
    init(
        pictures: MediaPictureCache,
        tables: LookUpTableCache,
        fonts: FontLibrary
    ) {
        self.pictures = pictures
        self.tables = tables
        self.glyphDrawer = GlyphDrawer(fonts: fonts)
    }

    // MARK: - Public
    func draw(_ list: DisplayList) throws -> FrameContext {
        try draw(list, on: Raster(holding: list.size))
    }

    // MARK: - Private
    private func draw(
        _ list: DisplayList,
        on raster: Raster
    ) throws -> FrameContext {
        let frame = try FrameContext(width: raster.width, height: raster.height, compositing: list.compositing)
        frame.context.setFillColor(list.background.cgColor)
        frame.context.fill(frame.bounds)

        for (index, item) in list.items.enumerated() {
            guard let mode = BlendMode(rawValue: item.blend) else {
                throw QuartzError.unsupportedBlend(name: item.blend, place: "items[\(index)].blend")
            }
            guard item.opacity > 0 else { continue }

            let drawing = try self.drawing(of: item, over: frame, on: raster, seed: list.seed)
            if mode == .normal {
                try draw(item, drawing: drawing, on: raster, in: frame)
            } else {
                let layer = try FrameContext(width: frame.width, height: frame.height, compositing: list.compositing)
                try draw(item, drawing: drawing, on: raster, in: layer)
                let blended = try Blender()
                    .composite(layer.ciImage(), over: frame.ciImage(), mode: mode, compositing: list.compositing)
                try frame.replace(with: blended)
            }
        }

        return frame
    }

    private func draw(
        _ item: DisplayItem,
        drawing: (CGContext) throws -> Void,
        on raster: Raster,
        in frame: FrameContext
    ) throws {
        let context = frame.context
        context.saveGState()
        defer { context.restoreGState() }

        // An item with a shadow is masked in the layer it casts the shadow from.
        let shadow = shadow(of: item.content)
        if shadow == nil {
            try mask(context, by: item, over: raster.bounds, at: raster.bounds, on: raster)
        }

        guard item.opacity < 1 else {
            try paint(item, drawing: drawing, casting: shadow, on: raster, in: frame)
            return
        }

        context.setAlpha(item.opacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        defer { context.endTransparencyLayer() }
        try paint(item, drawing: drawing, casting: shadow, on: raster, in: frame)
    }

    // Multiplies the alpha of what the context draws after it by the item's masks' result and its track matte's value
    // over `region` of the raster's pixels, which lies at `bounds` of the context's coordinates. Both are multiplied in
    // floating point, so the context clips once.
    private func mask(
        _ context: CGContext,
        by item: DisplayItem,
        over region: CGRect,
        at bounds: CGRect,
        on raster: Raster
    ) throws {
        let masks = item.mask.isEmpty
            ? nil
            : try MaskDrawer().values(of: item.mask, over: region, on: raster.transform)
        let matte = try item.trackMatte.map { trackMatte in
            try TrackMatteDrawer().values(
                of: trackMatte,
                source: try image(of: trackMatte.source, on: raster),
                over: region
            )
        }
        let factors = [masks, matte].compactMap { $0 }
        guard let first = factors.first else { return }

        let values = factors.dropFirst().reduce(first) { product, values in zip(product, values).map(*) }

        let image = try CGImage.coverage(of: values, width: Int(region.width), height: Int(region.height))
        context.clipUpright(to: bounds, mask: image)
    }

    // The item carried by its transform onto the raster and cut to its reveal, over its shadow when it casts one.
    private func paint(
        _ item: DisplayItem,
        drawing: (CGContext) throws -> Void,
        casting shadow: DropShadow?,
        on raster: Raster,
        in frame: FrameContext
    ) throws {
        let context = frame.context
        let matrix = matrix(of: item, on: raster)
        guard let shadow else {
            context.concatenate(matrix)
            if let reveal = item.reveal { context.clip(to: CGRect(reveal)) }
            try drawing(context)
            return
        }

        let cast = CastShadow(shadow, through: matrix, rasterScale: raster.transform.lengthScale)
        try paint(item, drawing: drawing, castingFromLayer: cast, on: raster, in: frame)
    }

    private func shadow(of content: DisplayContent) -> DropShadow? {
        switch content {
        case let .picture(picture):
            picture.shadow

        case let .path(path):
            path.shadow

        case .glyphs, .adjust:
            nil
        }
    }

    // The item drawn on the raster and masked into a layer a margin wider than the raster on every side, so a shadow
    // cast into the raster from outside it is kept. The layer's alpha in the shadow's colour, blurred and moved, is
    // drawn below the layer, both in the frame's form.
    private func paint(
        _ item: DisplayItem,
        drawing: (CGContext) throws -> Void,
        castingFromLayer shadow: CastShadow,
        on raster: Raster,
        in frame: FrameContext
    ) throws {
        let context = frame.context
        let compositing = frame.compositing
        let margin = shadow.margin
        let layer = try FrameContext(
            width: context.width + 2 * margin,
            height: context.height + 2 * margin,
            compositing: compositing
        )
        let region = CGRect(x: 0, y: 0, width: layer.width, height: layer.height)
            .offsetBy(dx: CGFloat(-margin), dy: CGFloat(-margin))
        try mask(layer.context, by: item, over: region, at: layer.bounds, on: raster)
        layer.context.translateBy(x: CGFloat(margin), y: CGFloat(margin))
        layer.context.concatenate(matrix(of: item, on: raster))
        if let reveal = item.reveal { layer.context.clip(to: CGRect(reveal)) }
        try drawing(layer.context)

        let picture = try layer.ciImage()
        var tinted = CIImage(color: CIColor(cgColor: shadow.color.cgColor))
            .cropped(to: picture.extent)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: picture])
        if shadow.blur > 0 {
            tinted = tinted.applyingGaussianBlur(sigma: shadow.blur)
        }
        // Core Image counts rows from the bottom, so a shadow moved down moves to a smaller y.
        let moved = tinted.transformed(by: CGAffineTransform(translationX: shadow.offset.width, y: -shadow.offset.height))
        let shown = CGRect(x: margin, y: margin, width: context.width, height: context.height)
        let bounds = CGRect(x: 0, y: 0, width: context.width, height: context.height)

        context.drawUpright(try FrameContext.cgImage(of: moved, in: shown, compositing: compositing), in: bounds)
        context.drawUpright(try FrameContext.cgImage(of: picture, in: shown, compositing: compositing), in: bounds)
    }

    // The item's own coordinates into the raster's pixels.
    private func matrix(
        of item: DisplayItem,
        on raster: Raster
    ) -> CGAffineTransform {
        CGAffineTransform(item.transform).concatenating(raster.transform)
    }

    // What the item draws in its own coordinates. Pictures are read and an adjustment's backdrop filtered before it,
    // since a blend mode draws it into a layer of its own.
    private func drawing(
        of item: DisplayItem,
        over frame: FrameContext,
        on raster: Raster,
        seed: Int
    ) throws -> (CGContext) throws -> Void {
        switch item.content {
        case let .picture(picture):
            let matrix = matrix(of: item, on: raster)
            let source = try image(of: picture, shownBy: matrix, on: raster)
            let matte = try picture.matte.flatMap { try image(of: $0, in: picture, shownBy: matrix, on: raster) }
            if picture.matte != nil, matte == nil { return { _ in } }

            return { [tables] context in
                try PictureDrawer(tables: tables).draw(
                    picture,
                    source: source,
                    matte: matte,
                    seed: seed,
                    carriedBy: item.transform,
                    compositing: frame.compositing,
                    in: context
                )
            }

        case let .path(path):
            return { context in PathDrawer().draw(path, carriedBy: item.transform, in: context) }

        case let .glyphs(glyphs):
            return { [glyphDrawer] context in try glyphDrawer.draw(glyphs, carriedBy: item.transform, in: context) }

        case let .adjust(adjust):
            return try adjusted(adjust, transform: item.transform, over: frame, on: raster, seed: seed)
        }
    }

    // A nested list is drawn on the part of the raster its picture lands in and on the part of the list its region
    // shows, each grown by how far what is drawn reads past it, and is nil when none of it lands there.
    private func image(
        of picture: PictureItem,
        shownBy matrix: CGAffineTransform,
        on raster: Raster
    ) throws -> SourceImage? {
        switch picture.source {
        case let .media(frame):
            guard frame.media.page != nil else { return SourceImage(media: try pictures.image(of: frame)) }

            return try pageImage(of: frame, in: picture, shownBy: matrix, on: raster)

        case let .displayList(list):
            let size = CGSize(width: list.size.width, height: list.size.height)
            guard let placement = picture.placement(ofSourceSized: size) else { return nil }

            let margin = reach(of: picture, through: matrix, rasterScale: raster.transform.lengthScale)
            let region = picture.rectangle.map(CGRect.init) ?? CGRect(origin: .zero, size: size)
            let listMargin = reach(of: list)
            guard
                let nested = Raster(
                    showing: list.size,
                    region: region.insetBy(dx: -listMargin, dy: -listMargin),
                    through: placement.concatenating(matrix),
                    within: raster.bounds.insetBy(dx: -margin, dy: -margin)
                )
            else {
                return nil
            }

            return SourceImage(try image(of: list, on: nested), of: list.size, drawnOn: nested)
        }
    }

    // A page picture is read in the part of the picture's region the raster shows, grown by how far what is drawn
    // reads past it.
    private func pageImage(
        of frame: MediaFrame,
        in picture: PictureItem,
        shownBy matrix: CGAffineTransform,
        on raster: Raster
    ) throws -> SourceImage? {
        let size = try pictures.pageSize(of: frame)
        guard let placement = picture.placement(ofSourceSized: CGSize(width: size.width, height: size.height)) else {
            return nil
        }

        return try pageImage(
            of: frame,
            sized: size,
            within: picture.rectangle.map(CGRect.init),
            shownBy: placement.concatenating(matrix),
            reaching: reach(of: picture, through: matrix, rasterScale: raster.transform.lengthScale),
            on: raster
        )
    }

    // A transition matte's picture, stretched over the destination. A page is read by the rule of a page picture at
    // the scale the whole map shows it at, its stretch over the destination and then `matrix`, in the part the raster
    // shows grown by how far the picture and the matte's resampling read past it. It is nil where none of it is shown.
    private func image(
        of matte: PictureMatte,
        in picture: PictureItem,
        shownBy matrix: CGAffineTransform,
        on raster: Raster
    ) throws -> SourceImage? {
        guard matte.frame.media.page != nil else { return SourceImage(media: try pictures.image(of: matte.frame)) }

        let size = try pictures.pageSize(of: matte.frame)
        let destination = picture.destination
        let stretch = CGAffineTransform(
            a: destination.width / size.width,
            b: 0,
            c: 0,
            d: destination.height / size.height,
            tx: destination.x,
            ty: destination.y
        )
        let margin = reach(of: picture, through: matrix, rasterScale: raster.transform.lengthScale)

        return try pageImage(
            of: matte.frame,
            sized: size,
            within: nil,
            shownBy: stretch.concatenating(matrix),
            reaching: margin + Self.matteResamplingReach,
            on: raster
        )
    }

    // A page is drawn from one picture the decoder gives at a scale its frame alone decides (FRAMES-20 Pictures): the
    // longer axis stretch of `map`, from the page's media pixels to the raster's pixels, rounded up to a power of two.
    // The picture is the whole page where the decoder holds it at that scale in at most `wholePagePixels`, so a pan at
    // one scale reads one picture. Otherwise it is the part of `region`, the whole page where it is nil, that lands on
    // the raster grown by `margin` of its pixels, at that scale or at the largest scale at which the decoder holds that
    // part. What of the picture lies outside the region is cut off by the destination's outline before a filter reads
    // it. It is nil where `map` is degenerate or none of the region lands there.
    private func pageImage(
        of frame: MediaFrame,
        sized size: Size,
        within region: CGRect?,
        shownBy map: CGAffineTransform,
        reaching margin: CGFloat,
        on raster: Raster
    ) throws -> SourceImage? {
        guard map.a * map.d - map.b * map.c != 0 else { return nil }

        let pageSize = CGSize(width: size.width, height: size.height)
        let stretch = map.axisScale
        let scale = pow(2, log2(max(stretch.width, stretch.height)).rounded(.up))
        if
            let whole = PageRegion(wholePageOf: size, scale: scale, largest: pictures.largestPictureSide),
            whole.width * whole.height <= Self.wholePagePixels
        {
            let image = try pictures.image(of: frame, region: whole, scale: scale)
            return SourceImage(image, of: pageSize, transform: CGAffineTransform(scaleX: scale, y: scale))
        }

        let page = CGRect(origin: .zero, size: pageSize)
        let visible = raster.bounds.insetBy(dx: -margin, dy: -margin)
            .applying(map.inverted())
            .intersection(region?.intersection(page) ?? page)
        guard !visible.isNull, !visible.isEmpty else { return nil }

        let largest = CGFloat(pictures.largestPictureSide)
        let held = min(scale, largest / max(visible.width, visible.height))
        let left = (visible.minX * held).rounded(.down)
        let top = (visible.minY * held).rounded(.down)
        let part = PageRegion(
            x: Int(left),
            y: Int(top),
            width: Int(min(largest, max(1, (visible.maxX * held).rounded(.up) - left))),
            height: Int(min(largest, max(1, (visible.maxY * held).rounded(.up) - top)))
        )
        let image = try pictures.image(of: frame, region: part, scale: held)

        return SourceImage(
            image,
            of: pageSize,
            transform: CGAffineTransform(a: held, b: 0, c: 0, d: held, tx: -left, ty: -top)
        )
    }

    private func image(
        of list: DisplayList,
        on raster: Raster
    ) throws -> CGImage {
        if let drawn = nested.first(where: { $0.list == list && $0.raster == raster }) { return drawn.image }

        let image = try draw(list, on: raster).image()
        nested.append((list, raster, image))

        return image
    }

    // How far past the raster, in its pixels, the picture's filter and shadow read its source, and the items of a list
    // it shows read past what is drawn of the list.
    private func reach(
        of picture: PictureItem,
        through matrix: CGAffineTransform,
        rasterScale: CGFloat
    ) -> CGFloat {
        let scale = matrix.axisScale
        let filter = FilterChain(tables: tables).reach(of: picture.filter) * max(scale.width, scale.height)
        let shadow = picture.shadow.map { CGFloat(CastShadow($0, through: matrix, rasterScale: rasterScale).margin) } ?? 0
        var items = 0.0
        if
            case let .displayList(list) = picture.source,
            let placement = picture.placement(ofSourceSized: CGSize(width: list.size.width, height: list.size.height))
        {
            let shown = placement.concatenating(matrix).axisScale
            items = reach(of: list) * max(shown.width, shown.height)
        }

        return (filter + shadow + items).rounded(.up)
    }

    // How far past the edge of its raster, in its output pixels, a list's items read what is drawn on that raster. An
    // adjustment reads the backdrop the adjustments below it filtered, so their reaches add up. A track matte's source
    // is drawn on the same raster and read as far out as the item casts its shadow from. A nested list's own raster is
    // grown past this raster by its picture's reach, so it adds nothing here.
    private func reach(of list: DisplayList) -> CGFloat {
        let chain = FilterChain(tables: tables)
        var adjustments = 0.0
        var mattes = 0.0
        for item in list.items {
            if case let .adjust(adjust) = item.content {
                adjustments += chain.reach(of: adjust.filter)
            }
            if let trackMatte = item.trackMatte {
                let shadow = shadow(of: item.content)
                    .map { shadow in
                        CGFloat(CastShadow(shadow, through: CGAffineTransform(item.transform), rasterScale: 1).margin)
                    } ?? 0
                mattes = max(mattes, reach(of: trackMatte.source) + shadow)
            }
        }

        return adjustments + mattes
    }

    // The whole backdrop through the adjustment's filter, drawn back over the frame in the raster's pixels, which the
    // item's matrix, carrying only its reveal, is undone for. The filter's lengths are in the list's output pixels,
    // scaled onto the raster.
    private func adjusted(
        _ adjust: AdjustItem,
        transform: Frames.AffineTransform,
        over frame: FrameContext,
        on raster: Raster,
        seed: Int
    ) throws -> (CGContext) throws -> Void {
        let matrix = CGAffineTransform(transform).concatenating(raster.transform)
        guard matrix.a * matrix.d - matrix.b * matrix.c != 0 else { return { _ in } }

        let backdrop = try frame.ciImage()
        // Core Image counts rows from the bottom.
        let listFrame = CGRect(
            x: raster.frame.minX,
            y: CGFloat(raster.height) - raster.frame.maxY,
            width: raster.frame.width,
            height: raster.frame.height
        )
        let filtered = try FilterChain(tables: tables)
            .apply(
                adjust.filter,
                to: backdrop,
                seed: seed,
                scale: raster.transform.lengthScale,
                frame: listFrame,
                compositing: frame.compositing
            )
            .cropped(to: backdrop.extent)
        let image = try FrameContext.cgImage(of: filtered, in: backdrop.extent, compositing: frame.compositing)

        return { context in
            context.concatenate(matrix.inverted())
            context.drawUpright(image, in: frame.bounds)
        }
    }
}
