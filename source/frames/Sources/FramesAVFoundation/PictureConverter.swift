//
//  PictureConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import CoreImage
import Foundation
import Frames

// Renders a decoded image, its samples taken as the file stores them with no colour matched, into a picture: working
// values at depth `halfFloat`, or an analysis picture at depth `eight`, RGBA with premultiplied alpha, rows top first.
// The colour is converted by the fixed formulas of `MediaColorConversion`, each pixel unpremultiplied first.
struct PictureConverter: Sendable {
    // MARK: - Property
    private let context: CIContext

    // MARK: - Initializer
    init() {
        context = CIContext(options: [
            .workingColorSpace: NSNull(),
            .outputColorSpace: NSNull(),
            .workingFormat: CIFormat.RGBAf,
            .cacheIntermediates: false
        ])
    }

    // MARK: - Public
    // Working values, an HDR picture tone mapped by `toneMapping` where it is given.
    func picture(
        from image: CIImage,
        conversion: MediaColorConversion,
        toneMapping: ToneMapping?
    ) -> Bitmap {
        var (samples, width, height) = encodedSamples(of: image)
        if !conversion.isIdentity {
            samples.withUnsafeMutableBufferPointer { pixels in
                pixels.convertColors { conversion.working($0, toneMapping: toneMapping) }
            }
        }

        let bytesPerRow = width * 4 * 2
        var pixels = Data(count: bytesPerRow * height)
        pixels.withUnsafeMutableBytes { buffer in
            let halves = buffer.bindMemory(to: Float16.self)
            for index in samples.indices {
                halves[index] = Float16(samples[index])
            }
        }

        return Bitmap(width: width, height: height, depth: .halfFloat, bytesPerRow: bytesPerRow, pixels: pixels)
    }

    // An analysis picture: an HDR picture tone mapped by `toneMapping` where it is given, and each channel of the
    // working value clipped to 0 to 1, then written at eight bits as the nearest code value.
    func analysisPicture(
        from image: CIImage,
        conversion: MediaColorConversion,
        toneMapping: ToneMapping?
    ) -> Bitmap {
        var (samples, width, height) = encodedSamples(of: image)
        samples.withUnsafeMutableBufferPointer { pixels in
            pixels.convertColors { conversion.working($0, toneMapping: toneMapping).clipped(to: 0...1) }
        }

        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)
        pixels.withUnsafeMutableBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            for index in samples.indices {
                bytes[index] = UInt8((min(max(samples[index], 0), 1) * 255).rounded())
            }
        }

        return Bitmap(width: width, height: height, depth: .eight, bytesPerRow: bytesPerRow, pixels: pixels)
    }

    // MARK: - Private
    // The image's samples as 32-bit floats, RGBA premultiplied, with its extent moved to the origin.
    private func encodedSamples(of image: CIImage) -> (samples: [Float], width: Int, height: Int) {
        let placed = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let width = Int(placed.extent.width.rounded())
        let height = Int(placed.extent.height.rounded())
        var samples = [Float](repeating: 0, count: width * height * 4)
        samples.withUnsafeMutableBytes { buffer in
            context.render(
                placed,
                toBitmap: buffer.baseAddress!,
                rowBytes: width * 4 * MemoryLayout<Float>.size,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                format: .RGBAf,
                colorSpace: nil
            )
        }

        return (samples, width, height)
    }
}
