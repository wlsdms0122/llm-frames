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
    // hold only part of it. The matte's source is stretched over the whole destination, and `frame` may hold only part
    // of that source.
    func apply(
        _ matte: PictureMatte,
        frame: SourceImage,
        to picture: CIImage,
        over destination: CGRect
    ) throws -> CIImage {
        let kernel = try KernelLibrary.shared.colorKernel(named: Self.kernelName)
        let image = frame.image
        let held = CGRect(x: 0, y: 0, width: image.width, height: image.height).applying(frame.transform.inverted())
        let horizontal = destination.width / frame.size.width
        let vertical = destination.height / frame.size.height
        let stretch = CGAffineTransform(
            a: held.width * horizontal / CGFloat(image.width),
            b: 0,
            c: 0,
            d: held.height * vertical / CGFloat(image.height),
            tx: destination.minX + held.minX * horizontal,
            ty: destination.maxY - held.maxY * vertical
        )
        let source = CIImage(cgImage: image, options: [.colorSpace: NSNull()])
        let stretched = source.clampedToExtent()
            .samplingLinear()
            .transformed(by: stretch, highQualityDownsample: true)
            .cropped(to: source.extent.applying(stretch))
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
