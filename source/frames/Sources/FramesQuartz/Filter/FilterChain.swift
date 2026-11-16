//
//  FilterChain.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Frames

// Applies a picture's filter operations in order to an image in the working space, each by its FRAMES-15 formula on
// sRGB-encoded values, its result clamped to 0 to 1 and cropped to the image's extent. Colour operations work on the
// unpremultiplied colour and keep alpha. Blur, sharpen, bloom and pixelate work on the premultiplied image, so a
// transparent pixel weighs nothing in a neighbour's mean, and blur, sharpen and bloom read the edge pixels extended
// outward.
struct FilterChain: Sendable {
    // MARK: - Property
    private let tables: LookUpTableCache

    // MARK: - Initializer
    init(tables: LookUpTableCache = .shared) {
        self.tables = tables
    }

    // MARK: - Public
    // `seed` is the display list's, which every `grain` operation draws its noise from.
    func apply(
        _ operations: [ResolvedFilterOperation],
        to image: CIImage,
        seed: Int
    ) throws -> CIImage {
        let library = try KernelLibrary.shared.get()
        var result = image
        for operation in operations {
            result = try apply(operation, to: result, seed: seed, library: library).cropped(to: image.extent)
        }

        return result
    }

    // MARK: - Private
    private func apply(
        _ operation: ResolvedFilterOperation,
        to image: CIImage,
        seed: Int,
        library: KernelLibrary
    ) throws -> CIImage {
        switch operation {
        case let .exposure(ev):
            return try color("filterExposure", image, [ev], library)

        case let .contrast(amount):
            return try color("filterContrast", image, [amount], library)

        case let .saturation(amount):
            return try color("filterSaturation", image, [amount], library)

        case let .temperature(kelvin):
            let gain = ChannelGain(kelvin: kelvin)

            return try color("filterTemperature", image, [CIVector(x: gain.red, y: gain.green, z: gain.blue)], library)

        case let .hue(degrees):
            return try color("filterHue", image, [degrees], library)

        case let .sepia(amount):
            return try color("filterSepia", image, [amount], library)

        case let .levels(input, output):
            let arguments = [CIVector(x: input[0], y: input[1]), CIVector(x: output[0], y: output[1])]

            return try color("filterLevels", image, arguments, library)

        case let .lut(file, amount):
            return try lookUp(image, table: try tables.table(of: file), amount: amount, library: library)

        case let .blur(radius):
            return try color("filterClamp", blurred(image, radius: radius), [], library)

        case let .sharpen(amount, radius):
            return try color("filterSharpen", image, [blurred(image, radius: radius), amount], library)

        case let .bloom(amount, radius, tint):
            let bright = try color("filterBloomBright", image, [], library)
            let glow = blurred(bright, radius: radius)
            let tint = tint.map { CIVector(premultiplied: $0) } ?? CIVector(x: 1, y: 1, z: 1, w: 1)

            return try color("filterBloomAdd", image, [glow, amount, tint], library)

        case let .vignette(amount, radius):
            let extent = image.extent
            let centre = CIVector(x: extent.midX, y: extent.midY)
            let halfDiagonal = (extent.width * extent.width + extent.height * extent.height).squareRoot() / 2

            return try color("filterVignette", image, [amount, radius, centre, halfDiagonal], library)

        case let .pixelate(size):
            return try color("filterClamp", pixelated(image, size: size, library: library), [], library)

        case let .grain(amount, size):
            let topLeft = CIVector(x: image.extent.minX, y: image.extent.maxY)
            let bits = UInt32(truncatingIfNeeded: seed)
            let seed = CIVector(x: Double(bits & 0xFFFF), y: Double(bits >> 16))

            return try color("filterGrain", image, [amount, size, topLeft, seed], library)
        }
    }

    // Applies the colour kernel `name` over the image's extent, the image first and then `arguments`.
    private func color(
        _ name: String,
        _ image: CIImage,
        _ arguments: [Any],
        _ library: KernelLibrary
    ) throws -> CIImage {
        let kernel = try library.colorKernel(named: name)
        guard let result = kernel.apply(extent: image.extent, arguments: [image] + arguments) else {
            throw QuartzError.unappliedKernel(name: name)
        }

        return result
    }

    // The Gaussian blur of standard deviation `radius`, reading the edge pixels extended outward.
    private func blurred(
        _ image: CIImage,
        radius: Double
    ) -> CIImage {
        image.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: image.extent)
    }

    private func lookUp(
        _ image: CIImage,
        table: LookUpTable,
        amount: Double,
        library: KernelLibrary
    ) throws -> CIImage {
        let name = "filterLookUp"
        let kernel = try library.generalKernel(named: name)
        let tableExtent = table.image.extent
        let arguments: [Any] = [image, table.image, Double(table.size), table.domainMin, table.domainMax, amount]
        guard let result = kernel.apply(
            extent: image.extent,
            roiCallback: { index, rect in index == 0 ? rect : tableExtent },
            arguments: arguments
        )
        else {
            throw QuartzError.unappliedKernel(name: name)
        }

        return result
    }

    // Square blocks `size` pixels across on a grid from the extent's top left corner, each the mean of the pixels
    // whose centres lie in it: a box average at block resolution, then each pixel takes its block's mean.
    private func pixelated(
        _ image: CIImage,
        size: Double,
        library: KernelLibrary
    ) throws -> CIImage {
        let extent = image.extent
        let bounds = CIVector(x: extent.minX, y: extent.minY, z: extent.width, w: extent.height)
        let blockExtent = CGRect(
            x: 0,
            y: 0,
            width: ((extent.width - 0.5) / size).rounded(.down) + 1,
            height: ((extent.height - 0.5) / size).rounded(.down) + 1
        )
        let meanName = "filterBlockMean"
        let fillName = "filterBlockFill"
        let mean = try library.generalKernel(named: meanName)
        let fill = try library.generalKernel(named: fillName)
        guard let blocks = mean.apply(
            extent: blockExtent,
            roiCallback: { _, rect in
                CGRect(
                    x: extent.minX + rect.minX * size - 1,
                    y: extent.maxY - rect.maxY * size - 1,
                    width: rect.width * size + 2,
                    height: rect.height * size + 2
                )
                .intersection(extent)
            },
            arguments: [image, size, bounds]
        )
        else {
            throw QuartzError.unappliedKernel(name: meanName)
        }
        guard let result = fill.apply(
            extent: extent,
            roiCallback: { _, _ in blockExtent },
            arguments: [blocks, size, bounds]
        )
        else {
            throw QuartzError.unappliedKernel(name: fillName)
        }

        return result
    }
}
