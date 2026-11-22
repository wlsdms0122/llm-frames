//
//  PlaneMovie.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/22/26.
//

import CoreGraphics
import Foundation
import Frames

// Writes a grey video whose frame i shows `poster` with its corners at `placement(i)`, carried there by the one
// homography that takes them so and read by bilinear interpolation, over `background` at its own pixels, and a
// checkered bar over both at `occluder(i)` where there is one. Each pixel is the mean of `samples` by `samples` points
// across it, so the picture is the poster's projection filtered by the pixel's area. Grey values are written as sRGB
// code values.
package struct PlaneMovie {
    // MARK: - Property
    private static let samples = 3

    private let size: Size
    private let frameTimes: [Double]
    private let end: Double
    private let poster: GreyTexture
    private let background: GreyTexture
    private let placement: (Int) -> Quad
    private let occluder: (Int) -> Rectangle?

    // MARK: - Initializer
    package init(
        size: Size,
        frameTimes: [Double],
        end: Double,
        poster: GreyTexture,
        background: GreyTexture,
        placement: @escaping (Int) -> Quad,
        occluder: @escaping (Int) -> Rectangle? = { _ in nil }
    ) {
        self.size = size
        self.frameTimes = frameTimes
        self.end = end
        self.poster = poster
        self.background = background
        self.placement = placement
        self.occluder = occluder
    }

    // MARK: - Public
    package func write(to path: String) async throws {
        try await MovieWriter(size: size, frameTimes: frameTimes, end: end).write(to: path) { canvas, index in
            guard let image = image(of: picture(at: index)) else { return }

            canvas.context.interpolationQuality = .none
            canvas.context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }

    // Frame `index`, its grey values row by row from the top left, each a whole number of 255ths.
    package func picture(at index: Int) -> [Float] {
        let width = Int(size.width)
        let height = Int(size.height)
        let posterRectangle = Quad(Rectangle(x: 0, y: 0, width: Double(poster.width), height: Double(poster.height)))
        // A homography of zeros puts every point behind the horizon, so a placement with no homography shows no poster.
        let toPoster = Homography(from: placement(index), to: posterRectangle)
            .map { ($0.a, $0.b, $0.c, $0.d, $0.tx, $0.ty, $0.g, $0.h, $0.i) } ?? (0, 0, 0, 0, 0, 0, 0, 0, 0)
        let bar = occluder(index)
        let samples = Self.samples
        let posterWidth = poster.width
        let posterHeight = poster.height
        let backgroundWidth = background.width
        let backgroundHeight = background.height
        var values = [Float](repeating: 0, count: width * height)
        poster.values.withUnsafeBufferPointer { posterValues in
            background.values.withUnsafeBufferPointer { backgroundValues in
                values.withUnsafeMutableBufferPointer { values in
                    nonisolated(unsafe) let posterValues = posterValues
                    nonisolated(unsafe) let backgroundValues = backgroundValues
                    nonisolated(unsafe) let values = values
                    DispatchQueue.concurrentPerform(iterations: height) { row in
                        for column in 0..<width {
                            let backdrop = row < backgroundHeight && column < backgroundWidth
                                ? backgroundValues[row * backgroundWidth + column]
                                : 0.5
                            var sum: Float = 0
                            for down in 0..<samples {
                                for across in 0..<samples {
                                    let x = Double(column) + (Double(across) + 0.5) / Double(samples)
                                    let y = Double(row) + (Double(down) + 0.5) / Double(samples)
                                    if let bar, x >= bar.x, x < bar.x + bar.width, y >= bar.y, y < bar.y + bar.height {
                                        let isLight = (Int((x - bar.x) / 9) + Int((y - bar.y) / 13)) % 2 == 0
                                        sum += isLight ? 0.9 : 0.3
                                        continue
                                    }

                                    let w = toPoster.6 * x + toPoster.7 * y + toPoster.8
                                    let u = (toPoster.0 * x + toPoster.2 * y + toPoster.4) / w - 0.5
                                    let v = (toPoster.1 * x + toPoster.3 * y + toPoster.5) / w - 0.5
                                    guard
                                        w > 0,
                                        u >= 0,
                                        v >= 0,
                                        u <= Double(posterWidth - 1),
                                        v <= Double(posterHeight - 1)
                                    else {
                                        sum += backdrop
                                        continue
                                    }

                                    // The poster by bilinear interpolation between the centres of its pixels.
                                    let left = min(Int(u), posterWidth - 2)
                                    let top = min(Int(v), posterHeight - 2)
                                    let rightward = Float(u - Double(left))
                                    let downward = Float(v - Double(top))
                                    let corner = top * posterWidth + left
                                    let upper = posterValues[corner] * (1 - rightward) + posterValues[corner + 1] * rightward
                                    let lower = posterValues[corner + posterWidth] * (1 - rightward)
                                        + posterValues[corner + posterWidth + 1] * rightward
                                    sum += upper * (1 - downward) + lower * downward
                                }
                            }
                            let mean = sum / Float(samples * samples)
                            values[row * width + column] = (min(max(mean, 0), 1) * 255).rounded() / 255
                        }
                    }
                }
            }
        }

        return values
    }

    // MARK: - Private
    // The grey values as an opaque sRGB picture, each component the same code value.
    private func image(of values: [Float]) -> CGImage? {
        var bytes = [UInt8](repeating: 255, count: values.count * 4)
        for (index, value) in values.enumerated() {
            let code = UInt8((value * 255).rounded())
            bytes[index * 4] = code
            bytes[index * 4 + 1] = code
            bytes[index * 4 + 2] = code
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }

        return CGImage(
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(size.width) * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
