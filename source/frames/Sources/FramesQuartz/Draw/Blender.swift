//
//  Blender.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Frames

// Composites a layer over its backdrop by a blend mode's kernel, over the backdrop's extent, in the form `compositing`
// names: the context the result is computed in works in that form.
struct Blender {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func composite(
        _ layer: CIImage,
        over backdrop: CIImage,
        mode: BlendMode,
        compositing: Compositing
    ) throws -> CIImage {
        let kernel = try KernelLibrary.shared.colorKernel(named: mode.kernelName)
        let arguments: [Any] = [layer, backdrop, compositing.kernelArgument]
        guard let image = kernel.apply(extent: backdrop.extent, arguments: arguments) else {
            throw QuartzError.kernelFailed(name: mode.kernelName)
        }

        return image
    }

    // MARK: - Private
}
