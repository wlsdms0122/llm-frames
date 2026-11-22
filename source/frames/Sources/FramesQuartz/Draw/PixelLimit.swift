//
//  PixelLimit.swift
//  FramesQuartz
//
//  Created by JSilver on 11/22/26.
//

import CoreGraphics

// The pixel limit (FRAMES-20 Pictures): a bitmap drawn at the scale a picture is shown at, a nested list's raster or
// the resolution a picture is filtered at, holds at most `factor` times the pixels of the area it lands in, and past
// that is drawn at the largest scale the limit allows.
struct PixelLimit {
    // MARK: - Property
    // A list turned by an eighth turn needs twice the pixels of its frame to keep its scale.
    private static let factor = 2.0

    // MARK: - Initializer
    // MARK: - Public
    // The scale a bitmap covering `region`, in units, is drawn at when `wanted` pixels per unit are asked for along
    // each axis and it lands in `area`, in pixels: `wanted` within the limit, and past it `wanted` scaled down on both
    // axes by one factor to the limit.
    func scale(
        _ wanted: CGSize,
        covering region: CGSize,
        within area: CGSize
    ) -> CGSize {
        let pixels = region.width * wanted.width * region.height * wanted.height
        let limit = Self.factor * area.width * area.height
        guard pixels > limit else { return wanted }

        let reduction = (limit / pixels).squareRoot()

        return CGSize(width: wanted.width * reduction, height: wanted.height * reduction)
    }

    // MARK: - Private
}
