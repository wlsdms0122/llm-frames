//
//  MatteApplier.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreImage
import Frames

// Masks a picture by the luminance of its matte frame, stretched over the picture's destination.
struct MatteApplier {
    // MARK: - Property
    private static let kernelName = "matteLuma"

    // MARK: - Initializer
    // MARK: - Public
    // `picture` holds the destination's `size` at its top left, in Core Image's y-up coordinates.
    func apply(
        _ matte: PictureMatte,
        frame: CGImage,
        to picture: CIImage,
        size: Size
    ) throws -> CIImage {
        let kernel = try KernelLibrary.shared.get().colorKernel(named: Self.kernelName)
        let stretch = CGAffineTransform(
            a: size.width / CGFloat(frame.width),
            b: 0,
            c: 0,
            d: size.height / CGFloat(frame.height),
            tx: 0,
            ty: picture.extent.maxY - size.height
        )
        let stretched = CIImage(cgImage: frame)
            .samplingLinear()
            .transformed(by: stretch, highQualityDownsample: true)
        let arguments: [Any] = [
            picture,
            stretched,
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
}
