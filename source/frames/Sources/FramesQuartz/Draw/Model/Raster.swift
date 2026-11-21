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
    // The grid a homography's stretch is sampled on has this many steps along each side.
    private static let stretchSamples = 32

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

        self.init(size: size, visible: visible, scale: map.axisScale, area: area)
    }

    // The raster of a list of `size` carried by `map`, a homography from the list's coordinates into the pixels of the
    // bitmap that shows it, of which only `area` is drawn, as a picture with a corner pin shows its whole list (FRAMES-20
    // Pictures). It covers the part of the list that lands in the area, grown by `margin`, how far its items read past
    // what is drawn in the list's own pixels, at the largest factor by which the map stretches a length, in any
    // direction, at the points it carries into the area. Those are sampled on a grid over that part and at its corners.
    // Nil when none of the list lands in the area.
    init?(
        showing size: Size,
        through map: Homography,
        within area: CGRect,
        reading margin: CGFloat
    ) {
        let list = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let corners = map.inverse.corners(
            carrying: Rectangle(x: area.minX, y: area.minY, width: area.width, height: area.height),
            within: Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        )
        guard let left = corners.map(\.x).min(),
              let right = corners.map(\.x).max(),
              let top = corners.map(\.y).min(),
              let bottom = corners.map(\.y).max()
        else {
            return nil
        }

        let landing = area.insetBy(dx: -1, dy: -1)
        let grid = (0...Self.stretchSamples).flatMap { column in
            (0...Self.stretchSamples).map { row in
                Point(
                    x: left + (right - left) * Double(column) / Double(Self.stretchSamples),
                    y: top + (bottom - top) * Double(row) / Double(Self.stretchSamples)
                )
            }
        }
        let stretch = (corners + grid)
            .compactMap { point -> Double? in
                guard let image = map.apply(to: point), landing.contains(CGPoint(x: image.x, y: image.y)) else { return nil }

                return map.stretch(at: point)
            }
            .max()
        guard let stretch, stretch > 0 else { return nil }

        let visible = CGRect(x: left, y: top, width: right - left, height: bottom - top)
            .insetBy(dx: -margin, dy: -margin)
            .intersection(list)
        guard !visible.isNull, !visible.isEmpty else { return nil }

        self.init(size: size, visible: visible, scale: CGSize(width: stretch, height: stretch), area: area)
    }

    // The raster of `visible`, the part of a list of `size` drawn, at `scale` pixels per unit of the list, held to the
    // pixel limit against `area`.
    private init?(
        size: Size,
        visible: CGRect,
        scale: CGSize,
        area: CGRect
    ) {
        var scale = scale
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
