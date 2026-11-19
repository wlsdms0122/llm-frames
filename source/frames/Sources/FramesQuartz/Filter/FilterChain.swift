//
//  FilterChain.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Frames

// Applies a picture's filter entries in order to an image in the working space, each entry its operations in order,
// each on sRGB-encoded values, its result clamped to 0 to 1 and cropped to the image's extent. Colour operations work
// on the unpremultiplied colour and keep alpha. Blur, sharpen, bloom and pixelate work on the premultiplied image, so
// a transparent pixel weighs nothing in a neighbour's mean, and blur, sharpen and bloom read the edge pixels extended
// outward. An entry's result is its input mixed with its operations' result by its `mix`, premultiplied, and the next
// entry takes the mixed image.
struct FilterChain: Sendable {
    // MARK: - Property
    // Past four standard deviations a Gaussian holds less than a ten-thousandth of its weight.
    private static let blurReach = 4.0

    private let tables: LookUpTableCache

    // MARK: - Initializer
    init(tables: LookUpTableCache) {
        self.tables = tables
    }

    // MARK: - Public
    // `seed` is the display list's, which every `grain` operation draws its noise from. `scale` is the image's pixels
    // per unit of the operations' lengths. `frame` is the picture the operations stand for, in the image's
    // coordinates, which a vignette centres on and grains and pixelate blocks lie on a grid from, the image's extent
    // when nil; it differs when the image holds part of the picture at another scale.
    func apply(
        _ entries: [FilterEntry],
        to image: CIImage,
        seed: Int,
        scale: Double = 1,
        frame: CGRect? = nil
    ) throws -> CIImage {
        let library = KernelLibrary.shared
        let frame = frame ?? image.extent
        var result = image
        for entry in entries where entry.mix > 0 {
            var filtered = result
            for operation in entry.operations {
                filtered = try apply(
                    operation,
                    to: filtered,
                    seed: seed,
                    scale: scale,
                    frame: frame,
                    library: library
                )
                .cropped(to: image.extent)
            }
            result = entry.mix < 1 ? try color("filterMix", result, [filtered, entry.mix], library) : filtered
        }

        return result
    }

    // How far, in the operations' lengths, the chain reads pixels from: what lies further than this past a picture's
    // edge does not change the picture.
    func reach(of entries: [FilterEntry]) -> Double {
        entries.filter { $0.mix > 0 }.flatMap(\.operations).reduce(0) { reach, operation in
            switch operation {
            case let .blur(radius), let .sharpen(_, radius), let .bloom(_, radius, _):
                reach + Self.blurReach * radius

            case let .pixelate(size):
                reach + size

            case .exposure, .contrast, .saturation, .temperature, .hue, .sepia, .levels, .lut, .vignette, .grain:
                reach
            }
        }
    }

    // MARK: - Private
    private func apply(
        _ operation: ResolvedFilterOperation,
        to image: CIImage,
        seed: Int,
        scale: Double,
        frame: CGRect,
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

        case let .lut(file, amount, _):
            return try lookUp(image, table: try tables.table(of: file), amount: amount, library: library)

        case let .blur(radius):
            return try color("filterClamp", blurred(image, radius: radius * scale), [], library)

        case let .sharpen(amount, radius):
            return try color("filterSharpen", image, [blurred(image, radius: radius * scale), amount], library)

        case let .bloom(amount, radius, tint):
            let bright = try color("filterBloomBright", image, [], library)
            let glow = blurred(bright, radius: radius * scale)
            let tint = tint.map { CIVector(premultiplied: $0) } ?? CIVector(x: 1, y: 1, z: 1, w: 1)

            return try color("filterBloomAdd", image, [glow, amount, tint], library)

        case let .vignette(amount, radius):
            let centre = CIVector(x: frame.midX, y: frame.midY)
            let halfDiagonal = (frame.width * frame.width + frame.height * frame.height).squareRoot() / 2

            return try color("filterVignette", image, [amount, radius, centre, halfDiagonal], library)

        case let .pixelate(size):
            let pixelated = try pixelated(image, size: size * scale, frame: frame, library: library)

            return try color("filterClamp", pixelated, [], library)

        case let .grain(amount, size):
            let topLeft = CIVector(x: frame.minX, y: frame.maxY)
            let bits = UInt32(truncatingIfNeeded: seed)
            let seed = CIVector(x: Double(bits & 0xFFFF), y: Double(bits >> 16))

            return try color("filterGrain", image, [amount, size * scale, topLeft, seed], library)
        }
    }

    private func color(
        _ name: String,
        _ image: CIImage,
        _ arguments: [Any],
        _ library: KernelLibrary
    ) throws -> CIImage {
        let kernel = try library.colorKernel(named: name)
        guard let result = kernel.apply(extent: image.extent, arguments: [image] + arguments) else {
            throw QuartzError.kernelFailed(name: name)
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
        let kernel = try library.kernel(named: name)
        let tableExtent = table.image.extent
        let arguments: [Any] = [image, table.image, Double(table.size), table.domainMin, table.domainMax, amount]
        guard let result = kernel.apply(
            extent: image.extent,
            roiCallback: { index, rect in index == 0 ? rect : tableExtent },
            arguments: arguments
        )
        else {
            throw QuartzError.kernelFailed(name: name)
        }

        return result
    }

    // Square blocks `size` pixels across on a grid from the frame's top left corner, each the mean of the pixels
    // whose centres lie in it: a box average at block resolution, then each pixel takes its block's mean. When the
    // grid does not start at the image's top left corner, the image's edge pixels extended out to the grid fill the
    // blocks its left and top edges cut.
    private func pixelated(
        _ image: CIImage,
        size: Double,
        frame: CGRect,
        library: KernelLibrary
    ) throws -> CIImage {
        let left = frame.minX + ((image.extent.minX - frame.minX) / size).rounded(.down) * size
        let top = frame.maxY - ((frame.maxY - image.extent.maxY) / size).rounded(.down) * size
        let extent = CGRect(
            x: left,
            y: image.extent.minY,
            width: image.extent.maxX - left,
            height: top - image.extent.minY
        )
        let image = extent == image.extent ? image : image.clampedToExtent().cropped(to: extent)
        let bounds = CIVector(x: extent.minX, y: extent.minY, z: extent.width, w: extent.height)
        let blockExtent = CGRect(
            x: 0,
            y: 0,
            width: ((extent.width - 0.5) / size).rounded(.down) + 1,
            height: ((extent.height - 0.5) / size).rounded(.down) + 1
        )
        let meanName = "filterBlockMean"
        let fillName = "filterBlockFill"
        let mean = try library.kernel(named: meanName)
        let fill = try library.kernel(named: fillName)
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
            throw QuartzError.kernelFailed(name: meanName)
        }
        guard let result = fill.apply(
            extent: extent,
            roiCallback: { _, _ in blockExtent },
            arguments: [blocks, size, bounds]
        )
        else {
            throw QuartzError.kernelFailed(name: fillName)
        }

        return result
    }
}
