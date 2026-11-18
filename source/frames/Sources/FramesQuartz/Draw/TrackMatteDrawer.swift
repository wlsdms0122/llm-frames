//
//  TrackMatteDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

import CoreGraphics
import CoreImage
import Frames

// Takes a track matte's value at each pixel of a region of output pixels from its source, drawn at the size of the
// list that holds its item (`TrackMatteKernelSource`). Outside the source the matte is transparent, so its value is 0
// there, and 1 when inverted.
struct TrackMatteDrawer {
    // MARK: - Property
    private static let kernelName = "trackMatte"

    // MARK: - Initializer
    // MARK: - Public
    // `source` is the matte's source drawn, and `region` is in output pixels, in whole pixels. The values are rows from
    // the top.
    func values(
        of trackMatte: ItemTrackMatte,
        source: CGImage,
        over region: CGRect
    ) throws -> [Double] {
        let kernel = try KernelLibrary.shared.colorKernel(named: Self.kernelName)
        let width = Int(region.width)
        let height = Int(region.height)
        // Core Image counts rows from the bottom of the source.
        let bounds = CGRect(
            x: region.minX,
            y: CGFloat(source.height) - region.maxY,
            width: region.width,
            height: region.height
        )
        let arguments: [Any] = [
            CIImage(cgImage: source),
            trackMatte.mode == .luma ? 1.0 : 0.0,
            trackMatte.isInverted ? 1.0 : 0.0
        ]
        guard let matte = kernel.apply(extent: bounds, arguments: arguments) else {
            throw QuartzError.kernelFailed(name: Self.kernelName)
        }

        var values = [Float](repeating: 0, count: width * height)
        values.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else { return }

            WorkingSpace.context.render(
                matte,
                toBitmap: pointer,
                rowBytes: width * MemoryLayout<Float>.size,
                bounds: bounds,
                format: .Rf,
                colorSpace: nil
            )
        }

        return values.map(Double.init)
    }

    // MARK: - Private
}
