//
//  Raster.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Foundation
import Frames

// The bitmap a display list is drawn into: its size in whole pixels and `transform`, which carries the list's
// coordinates into the bitmap's pixels, y pointing down. `transform` only scales and moves, so the list's frame lands
// on an upright rectangle. A nested list's raster covers the part of the list shown in the frame of the list that
// holds it, at the scale it is shown at, so its items come out as sharp as they would drawn in place.
struct Raster: Equatable {
    // MARK: - Property
    // A nested list's bitmap holds at most this many times the pixels of the area it is shown in. A list turned by an
    // eighth turn needs twice the pixels of its frame to keep its scale, and a larger one is drawn at a smaller scale.
    private static let pixelLimit = 2.0

    let width: Int
    let height: Int
    let transform: CGAffineTransform
    // The list's frame in the bitmap's pixels.
    let frame: CGRect

    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }

    // MARK: - Initializer
    init(holding size: Size) {
        self.width = Int(size.width.rounded(.up))
        self.height = Int(size.height.rounded(.up))
        self.transform = .identity
        self.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }

    // The raster of a list of `size` whose `region` is shown through `map`, which carries the list's coordinates into
    // the pixels of the bitmap that shows it, and of which only `area` is drawn. Nil when none of the region lands in
    // the area.
    init?(
        showing size: Size,
        region: CGRect,
        through map: CGAffineTransform,
        within area: CGRect
    ) {
        let shown = region.intersection(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        guard !shown.isNull, !shown.isEmpty, map.a * map.d - map.b * map.c != 0 else { return nil }

        let visible = area.applying(map.inverted()).intersection(shown)
        guard !visible.isNull, !visible.isEmpty else { return nil }

        var scale = map.axisScale
        let pixels = visible.width * scale.width * visible.height * scale.height
        let limit = Self.pixelLimit * area.width * area.height
        if pixels > limit {
            let factor = (limit / pixels).squareRoot()
            scale = CGSize(width: scale.width * factor, height: scale.height * factor)
        }

        let left = (visible.minX * scale.width).rounded(.down)
        let top = (visible.minY * scale.height).rounded(.down)
        let right = (visible.maxX * scale.width).rounded(.up)
        let bottom = (visible.maxY * scale.height).rounded(.up)
        guard right > left, bottom > top else { return nil }

        let transform = CGAffineTransform(a: scale.width, b: 0, c: 0, d: scale.height, tx: -left, ty: -top)
        self.width = Int(right - left)
        self.height = Int(bottom - top)
        self.transform = transform
        self.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height).applying(transform)
    }

    // MARK: - Public
    // MARK: - Private
}
