//
//  FrameDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Frames

// Draws the display lists of one output frame: the list over its background, items bottom first, each carried by its
// transform and cut to its reveal in its own coordinates, then its alpha multiplied by its masks' result in output
// pixels (`MaskDrawer`), over the shadow it casts from that cut picture, which the masks do not cut. A `normal` item is
// drawn source-over by Core Graphics, and any other blend mode draws the item into a transparent layer that the mode's
// W3C kernel composites over the backdrop. Opacity below 1 and the blend mode apply to the item and its shadow as a
// whole. Nested lists are drawn once per frame at their own size.
final class FrameDrawer {
    // MARK: - Property
    private let pictures: MediaPictureCache
    private let tables: LookUpTableCache
    private let glyphDrawer: GlyphDrawer

    private var nested: [(list: DisplayList, image: CGImage)] = []

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
        let frame = try FrameContext(holding: list.size)
        frame.context.setFillColor(list.background.cgColor)
        frame.context.fill(frame.bounds)

        for (index, item) in list.items.enumerated() {
            guard let mode = BlendMode(rawValue: item.blend) else {
                throw QuartzError.unsupportedBlend(name: item.blend, place: "items[\(index)].blend")
            }
            guard item.opacity > 0 else { continue }

            let drawing = try self.drawing(of: item, over: frame, seed: list.seed)
            if mode == .normal {
                try draw(item, drawing: drawing, in: frame.context)
            } else {
                let layer = try FrameContext(width: frame.width, height: frame.height)
                try draw(item, drawing: drawing, in: layer.context)
                try frame.replace(with: try Blender().composite(layer.ciImage(), over: frame.ciImage(), mode: mode))
            }
        }

        return frame
    }

    // MARK: - Private
    private func draw(
        _ item: DisplayItem,
        drawing: (CGContext) throws -> Void,
        in context: CGContext
    ) throws {
        context.saveGState()
        defer { context.restoreGState() }

        // An item with a shadow is masked in the layer it casts the shadow from.
        let shadow = shadow(of: item.content)
        if shadow == nil {
            let bounds = CGRect(x: 0, y: 0, width: context.width, height: context.height)
            try mask(context, by: item.mask, over: bounds, at: bounds)
        }

        guard item.opacity < 1 else {
            try paint(item, drawing: drawing, casting: shadow, in: context)
            return
        }

        context.setAlpha(item.opacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        defer { context.endTransparencyLayer() }
        try paint(item, drawing: drawing, casting: shadow, in: context)
    }

    // Multiplies the alpha of what the context draws after it by the masks' result over `region` of output pixels,
    // which lies at `bounds` of the context's coordinates.
    private func mask(
        _ context: CGContext,
        by masks: [ItemMask],
        over region: CGRect,
        at bounds: CGRect
    ) throws {
        guard !masks.isEmpty else { return }

        context.clipUpright(to: bounds, mask: try MaskDrawer().image(of: masks, over: region))
    }

    // The item carried by its transform and cut to its reveal, over its shadow when it casts one.
    private func paint(
        _ item: DisplayItem,
        drawing: (CGContext) throws -> Void,
        casting shadow: DropShadow?,
        in context: CGContext
    ) throws {
        guard let shadow else {
            context.concatenate(CGAffineTransform(item.transform))
            if let reveal = item.reveal { context.clip(to: CGRect(reveal)) }
            try drawing(context)
            return
        }

        try paint(item, drawing: drawing, castingFromLayer: shadow, in: context)
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

    // The item drawn in output pixels and masked into a layer a margin wider than the frame on every side, so a shadow
    // cast into the frame from outside it is kept. The layer's alpha in the shadow's colour, blurred and moved, is
    // drawn below the layer. The shadow's radius and offset are in the item's own coordinates, so the transform carries
    // the offset and scales the radius by its area's square root.
    private func paint(
        _ item: DisplayItem,
        drawing: (CGContext) throws -> Void,
        castingFromLayer shadow: DropShadow,
        in context: CGContext
    ) throws {
        let matrix = CGAffineTransform(item.transform)
        let blur = shadow.radius * abs(matrix.a * matrix.d - matrix.b * matrix.c).squareRoot()
        let offset = CGSize(width: shadow.offset.x, height: shadow.offset.y).applying(matrix)
        let margin = Int((3 * blur + hypot(offset.width, offset.height)).rounded(.up)) + 1
        let layer = try FrameContext(width: context.width + 2 * margin, height: context.height + 2 * margin)
        let region = CGRect(x: 0, y: 0, width: layer.width, height: layer.height)
            .offsetBy(dx: CGFloat(-margin), dy: CGFloat(-margin))
        try mask(layer.context, by: item.mask, over: region, at: layer.bounds)
        layer.context.translateBy(x: CGFloat(margin), y: CGFloat(margin))
        layer.context.concatenate(matrix)
        if let reveal = item.reveal { layer.context.clip(to: CGRect(reveal)) }
        try drawing(layer.context)

        let picture = try layer.ciImage()
        var tinted = CIImage(color: CIColor(cgColor: shadow.color.cgColor))
            .cropped(to: picture.extent)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: picture])
        if blur > 0 {
            tinted = tinted.applyingGaussianBlur(sigma: blur)
        }
        // Core Image counts rows from the bottom, so a shadow moved down moves to a smaller y.
        let moved = tinted.transformed(by: CGAffineTransform(translationX: offset.width, y: -offset.height))
        let frame = CGRect(x: margin, y: margin, width: context.width, height: context.height)
        let bounds = CGRect(x: 0, y: 0, width: context.width, height: context.height)

        context.drawUpright(try FrameContext.cgImage(of: moved, in: frame), in: bounds)
        context.drawUpright(try FrameContext.cgImage(of: picture, in: frame), in: bounds)
    }

    // What the item draws in its own coordinates. Pictures are read and an adjustment's backdrop filtered before it,
    // since a blend mode draws it into a layer of its own.
    private func drawing(
        of item: DisplayItem,
        over frame: FrameContext,
        seed: Int
    ) throws -> (CGContext) throws -> Void {
        switch item.content {
        case let .picture(picture):
            let source = try image(of: picture.source)
            let matte = try picture.matte.map { try pictures.image(of: $0.frame) }
            return { [tables] context in
                try PictureDrawer(tables: tables).draw(picture, source: source, matte: matte, seed: seed, in: context)
            }

        case let .path(path):
            return { context in PathDrawer().draw(path, in: context) }

        case let .glyphs(glyphs):
            return { [glyphDrawer] context in try glyphDrawer.draw(glyphs, in: context) }

        case let .adjust(adjust):
            return try adjusted(adjust, transform: item.transform, over: frame, seed: seed)
        }
    }

    private func image(of source: PictureItemSource) throws -> CGImage {
        switch source {
        case let .media(frame):
            return try pictures.image(of: frame)

        case let .displayList(list):
            if let drawn = nested.first(where: { $0.list == list }) { return drawn.image }

            let image = try draw(list).image()
            nested.append((list, image))

            return image
        }
    }

    // The whole backdrop through the adjustment's filter, drawn back over the frame in output pixels, which the item's
    // transform, carrying only its reveal, is undone for.
    private func adjusted(
        _ adjust: AdjustItem,
        transform: Frames.AffineTransform,
        over frame: FrameContext,
        seed: Int
    ) throws -> (CGContext) throws -> Void {
        let matrix = CGAffineTransform(transform)
        guard matrix.a * matrix.d - matrix.b * matrix.c != 0 else { return { _ in } }

        let backdrop = try frame.ciImage()
        let chain = FilterChain(tables: tables)
        let filtered = try chain.apply(adjust.filter, to: backdrop, seed: seed).cropped(to: backdrop.extent)
        let image = try FrameContext.cgImage(of: filtered, in: backdrop.extent)

        return { context in
            context.concatenate(matrix.inverted())
            context.drawUpright(image, in: frame.bounds)
        }
    }
}
