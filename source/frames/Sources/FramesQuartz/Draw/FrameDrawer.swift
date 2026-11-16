//
//  FrameDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Frames

// Draws the display lists of one output frame: the list over its background, items bottom first, each cut to its mask
// in output pixels, carried by its transform and cut to its reveal in its own coordinates. A `normal` item is drawn
// source-over by Core Graphics, and any other blend mode draws the item into a transparent layer that the mode's W3C
// kernel composites over the backdrop. Opacity below 1 applies to the item as a whole. Nested lists are drawn once
// per frame at their own size.
final class FrameDrawer {
    // MARK: - Property
    private let pictures: MediaPictureCache
    private let glyphDrawer: GlyphDrawer

    private var nested: [(list: DisplayList, image: CGImage)] = []

    // MARK: - Initializer
    init(
        pictures: MediaPictureCache,
        fonts: FontLibrary
    ) {
        self.pictures = pictures
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
    ) rethrows {
        context.saveGState()
        defer { context.restoreGState() }

        if let mask = item.mask { context.clip(to: CGRect(mask)) }
        context.concatenate(CGAffineTransform(item.transform))
        if let reveal = item.reveal { context.clip(to: CGRect(reveal)) }

        guard item.opacity < 1 else {
            try drawing(context)
            return
        }

        context.setAlpha(item.opacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        defer { context.endTransparencyLayer() }
        try drawing(context)
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
            return { context in
                try PictureDrawer().draw(picture, source: source, matte: matte, seed: seed, in: context)
            }

        case let .fill(fill):
            return { context in ShapeDrawer().draw(fill, in: context) }

        case let .stroke(stroke):
            return { context in ShapeDrawer().draw(stroke, in: context) }

        case let .arrow(arrow):
            return { context in ShapeDrawer().draw(arrow, in: context) }

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

    // The backdrop under the adjustment's rectangle in output pixels, through its filter, drawn back where it was
    // read. The rectangle is in the item's own coordinates, the whole frame when it is nil.
    private func adjusted(
        _ adjust: AdjustItem,
        transform: Frames.AffineTransform,
        over frame: FrameContext,
        seed: Int
    ) throws -> (CGContext) throws -> Void {
        let matrix = CGAffineTransform(transform)
        let region = adjust.rectangle.map(CGRect.init) ?? frame.bounds
        let bounds = region.applying(matrix).integral.intersection(frame.bounds)
        guard !bounds.isNull, !bounds.isEmpty, matrix.a * matrix.d - matrix.b * matrix.c != 0 else {
            return { _ in }
        }

        // Core Image counts rows from the bottom.
        let extent = CGRect(
            x: bounds.minX,
            y: CGFloat(frame.height) - bounds.maxY,
            width: bounds.width,
            height: bounds.height
        )
        let backdrop = try frame.ciImage().cropped(to: extent)
        let filtered = try FilterChain().apply(adjust.filter, to: backdrop, seed: seed).cropped(to: extent)
        let image = try FrameContext.cgImage(of: filtered, in: extent)

        return { context in
            context.clip(to: region)
            context.concatenate(matrix.inverted())
            context.drawUpright(image, in: bounds)
        }
    }
}
