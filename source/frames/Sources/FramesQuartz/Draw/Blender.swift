//
//  Blender.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage

// Composites a layer over its backdrop by a blend mode's W3C kernel, over the backdrop's extent.
struct Blender {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func composite(
        _ layer: CIImage,
        over backdrop: CIImage,
        mode: BlendMode
    ) throws -> CIImage {
        let kernel = try KernelLibrary.shared.get().colorKernel(named: mode.kernelName)
        guard let image = kernel.apply(extent: backdrop.extent, arguments: [layer, backdrop]) else {
            throw QuartzError.kernelFailed(name: mode.kernelName)
        }

        return image
    }

    // MARK: - Private
}
