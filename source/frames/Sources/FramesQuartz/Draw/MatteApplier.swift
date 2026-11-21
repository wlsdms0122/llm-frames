//
//  MatteApplier.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Foundation
import Frames

// Masks a picture by the luma of its transition matte, an analysis picture stretched over the picture's destination
// (`MatteKernelSource`). The matte's values are read as they are, outside colour management, so the kernel takes them
// on the encoded form in either form of the picture. They are stretched by the value context in 32-bit floats, as
// Core Image's high quality resampling in half floats moves them by up to about 0.2%.
struct MatteApplier {
    // MARK: - Property
    private static let kernelName = "matteLuma"

    // MARK: - Initializer
    // MARK: - Public
    // `destination` is where the picture's destination lies in `picture`'s Core Image coordinates, y up, which may
    // hold only part of it.
    func apply(
        _ matte: PictureMatte,
        frame: CGImage,
        to picture: CIImage,
        over destination: CGRect
    ) throws -> CIImage {
        let kernel = try KernelLibrary.shared.colorKernel(named: Self.kernelName)
        let stretch = CGAffineTransform(
            a: destination.width / CGFloat(frame.width),
            b: 0,
            c: 0,
            d: destination.height / CGFloat(frame.height),
            tx: destination.minX,
            ty: destination.minY
        )
        let stretched = CIImage(cgImage: frame, options: [.colorSpace: NSNull()])
            .samplingLinear()
            .transformed(by: stretch, highQualityDownsample: true)
        let arguments: [Any] = [
            picture,
            values(of: stretched, over: picture.extent),
            matte.progress,
            matte.softness,
            matte.isInverted ? 1.0 : 0.0
        ]
        guard let image = kernel.apply(extent: picture.extent, arguments: arguments) else {
            throw QuartzError.kernelFailed(name: Self.kernelName)
        }

        return image
    }

    // MARK: - Private
    // The image's values over `extent`, computed by the value context and held in 32-bit floats.
    private func values(
        of image: CIImage,
        over extent: CGRect
    ) -> CIImage {
        let bounds = extent.integral
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        let rowBytes = width * 4 * MemoryLayout<Float>.size
        var pixels = [Float](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else { return }

            WorkingSpace.valueContext.render(
                image,
                toBitmap: pointer,
                rowBytes: rowBytes,
                bounds: bounds,
                format: .RGBAf,
                colorSpace: nil
            )
        }

        return CIImage(
            bitmapData: pixels.withUnsafeBufferPointer { Data(buffer: $0) },
            bytesPerRow: rowBytes,
            size: bounds.size,
            format: .RGBAf,
            colorSpace: nil
        )
        .transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
    }
}
