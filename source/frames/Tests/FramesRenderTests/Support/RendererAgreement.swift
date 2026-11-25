//
//  RendererAgreement.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

import Frames

// How far a renderer's frame lies from the reference's, by the classes of FRAMES-24 Tolerances. A flat pixel is one
// whose reference components differ from those of every pixel next to it, diagonals included, by at most 2^-8, so no
// edge and no detail of a resampled picture reaches it. Every other pixel is held to the bounds of a resampled picture
// and an edge.
struct RendererAgreement {
    // MARK: - Property
    private static let flatStep = 1.0 / 256

    // The largest difference of a flat pixel's component over max(1, |v|), and the mean difference over them.
    let flatLargest: Double
    let flatMean: Double
    // The largest difference of any other pixel's component, of its alpha, and the mean difference over them.
    let otherLargest: Double
    let otherAlphaLargest: Double
    let otherMean: Double
    let flatCount: Int
    let otherCount: Int

    var summary: String {
        "flat \(flatCount) px: largest \(flatLargest), mean \(flatMean); "
            + "other \(otherCount) px: largest \(otherLargest), alpha \(otherAlphaLargest), mean \(otherMean)"
    }

    // MARK: - Initializer
    init(
        of frame: Bitmap,
        against reference: Bitmap
    ) {
        precondition(frame.width == reference.width && frame.height == reference.height, "frames of two sizes")

        let width = reference.width
        let height = reference.height
        let values = Self.values(of: reference)
        let others = Self.values(of: frame)
        var flatLargest = 0.0
        var flatSum = 0.0
        var flatCount = 0
        var otherLargest = 0.0
        var otherAlphaLargest = 0.0
        var otherSum = 0.0
        var otherCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                var isFlat = true
                for dy in -1...1 where isFlat {
                    for dx in -1...1 where isFlat {
                        let nx = min(max(x + dx, 0), width - 1)
                        let ny = min(max(y + dy, 0), height - 1)
                        let neighbour = (ny * width + nx) * 4
                        for component in 0..<4 where abs(values[neighbour + component] - values[index + component]) > Self.flatStep {
                            isFlat = false
                        }
                    }
                }
                for component in 0..<4 {
                    let value = values[index + component]
                    let difference = abs(others[index + component] - value)
                    if isFlat {
                        flatLargest = max(flatLargest, difference / max(1, abs(value)))
                        flatSum += difference
                    } else {
                        otherLargest = max(otherLargest, difference)
                        if component == 3 { otherAlphaLargest = max(otherAlphaLargest, difference) }
                        otherSum += difference
                    }
                }
                if isFlat { flatCount += 1 } else { otherCount += 1 }
            }
        }

        self.flatLargest = flatLargest
        self.flatMean = flatCount > 0 ? flatSum / Double(flatCount * 4) : 0
        self.otherLargest = otherLargest
        self.otherAlphaLargest = otherAlphaLargest
        self.otherMean = otherCount > 0 ? otherSum / Double(otherCount * 4) : 0
        self.flatCount = flatCount
        self.otherCount = otherCount
    }

    // MARK: - Public
    // MARK: - Private
    // The bitmap's components, half floats, rows top first with no padding.
    private static func values(of bitmap: Bitmap) -> [Double] {
        precondition(bitmap.depth == .halfFloat, "a frame that is not of half floats")

        var values = [Double](repeating: 0, count: bitmap.width * bitmap.height * 4)
        bitmap.pixels.withUnsafeBytes { buffer in
            for y in 0..<bitmap.height {
                let row = buffer.baseAddress!.advanced(by: y * bitmap.bytesPerRow).assumingMemoryBound(to: Float16.self)
                for index in 0..<bitmap.width * 4 {
                    values[y * bitmap.width * 4 + index] = Double(row[index])
                }
            }
        }

        return values
    }
}
