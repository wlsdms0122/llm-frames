//
//  FilterChain.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Frames

// Applies a picture's filter entries in order to an image of working values, each entry its operations in order, each
// result cropped to the image's extent and clamped nowhere but in alpha. The image is computed in the form its
// `compositing` names, which every form-free formula takes, and each operation with a home converts to it
// (`FilterKernelSource`). Colour operations work on the unpremultiplied colour and keep alpha. Blur, sharpen, bloom,
// pixelate and displace work on the premultiplied image, so a transparent pixel weighs nothing in a neighbour's mean,
// and blur, sharpen, bloom and displace read the edge pixels extended outward. A displacement map is read through the
// decoder as its file's tags say, frame 0 of the still, and its values go to the kernel as the decoder gives them, in
// neither form. An entry's result is its input mixed with its operations' result by its `mix`, premultiplied, and the
// next entry takes the mixed image.
struct FilterChain: Sendable {
    // MARK: - Property
    // Past four standard deviations a Gaussian holds less than a ten-thousandth of its weight.
    private static let blurReach = 4.0

    private let tables: LookUpTableCache
    private let pictures: MediaPictureCache

    // MARK: - Initializer
    init(
        tables: LookUpTableCache,
        pictures: MediaPictureCache
    ) {
        self.tables = tables
        self.pictures = pictures
    }

    // MARK: - Public
    // `seed` is the display list's, which every `grain` operation draws its noise from. `scale` is the image's pixels
    // per unit of the operations' lengths. `frame` is the picture the operations stand for, in the image's
    // coordinates, which a vignette centres on, grains and pixelate blocks lie on a grid from and a displacement map is
    // laid over, the image's extent when nil; it differs when the image holds part of the picture at another scale. The result is computed in the
    // form `compositing` names, by the context of that form.
    func apply(
        _ entries: [FilterEntry],
        to image: CIImage,
        seed: Int,
        scale: Double = 1,
        frame: CGRect? = nil,
        compositing: Compositing
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
                    compositing: compositing,
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

            // A pixel reads at most `amount` from its centre on each axis, so its bilinear read takes only pixels that
            // begin less than `amount` past its edge.
            case let .displace(_, amount, _):
                reach + amount

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
        compositing: Compositing,
        library: KernelLibrary
    ) throws -> CIImage {
        let linear = compositing.kernelArgument

        switch operation {
        case let .exposure(ev):
            return try color("filterExposure", image, [ev, linear], library)

        case let .contrast(amount):
            return try color("filterContrast", image, [amount, linear], library)

        case let .saturation(amount):
            return try color("filterSaturation", image, [amount, linear], library)

        case let .temperature(kelvin):
            let gain = ChannelGain(kelvin: kelvin)
            let arguments: [Any] = [CIVector(x: gain.red, y: gain.green, z: gain.blue), linear]

            return try color("filterTemperature", image, arguments, library)

        case let .hue(degrees):
            return try color("filterHue", image, [degrees, linear], library)

        case let .sepia(amount):
            return try color("filterSepia", image, [amount, linear], library)

        case let .levels(input, output):
            let arguments: [Any] = [CIVector(x: input[0], y: input[1]), CIVector(x: output[0], y: output[1]), linear]

            return try color("filterLevels", image, arguments, library)

        case let .lut(file, amount, space):
            let table = try tables.table(of: file)

            return try lookUp(image, table: table, amount: amount, space: space, compositing: compositing, library: library)

        case let .blur(radius):
            return try color("filterClampAlpha", blurred(image, radius: radius * scale), [], library)

        case let .sharpen(amount, radius):
            return try color("filterSharpen", image, [blurred(image, radius: radius * scale), amount], library)

        case let .bloom(amount, radius, tint):
            let bright = try color("filterBloomBright", image, [linear], library)
            let glow = blurred(bright, radius: radius * scale)
            let tint = tint.map { CIVector(premultiplied: $0, compositing: compositing) }
                ?? CIVector(x: 1, y: 1, z: 1, w: 1)

            return try color("filterBloomAdd", image, [glow, amount, tint], library)

        case let .vignette(amount, radius):
            let centre = CIVector(x: frame.midX, y: frame.midY)
            let halfDiagonal = (frame.width * frame.width + frame.height * frame.height).squareRoot() / 2

            return try color("filterVignette", image, [amount, radius, centre, halfDiagonal], library)

        case let .displace(file, amount, offset):
            guard amount > 0 else { return image }

            let map = try pictures.image(of: MediaFrame(media: PinnedMedia(source: .file(file, frameTimes: nil)), index: 0))
            let move = Point(x: offset.x * scale, y: offset.y * scale)

            return try displaced(image, by: map, amount: amount * scale, offset: move, frame: frame, library: library)

        case let .pixelate(size):
            let pixelated = try pixelated(image, size: size * scale, frame: frame, library: library)

            return try color("filterClampAlpha", pixelated, [], library)

        case let .grain(amount, size):
            let topLeft = CIVector(x: frame.minX, y: frame.maxY)
            let bits = UInt32(truncatingIfNeeded: seed)
            let seed = CIVector(x: Double(bits & 0xFFFF), y: Double(bits >> 16))

            return try color("filterGrain", image, [amount, size * scale, topLeft, seed, linear], library)
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

    // A LUT built for `srgb` looks the working values up on the encoded form in its kernel. One built for another
    // space looks up the image converted to the values that space gives the LUT, its colours taken back to working
    // values, and its result is mixed with the image by `amount`.
    private func lookUp(
        _ image: CIImage,
        table: LookUpTable,
        amount: Double,
        space: LookUpTableSpace,
        compositing: Compositing,
        library: KernelLibrary
    ) throws -> CIImage {
        guard space != .srgb else {
            return try lookUp(image, table: table, amount: amount, linear: compositing.kernelArgument, library: library)
        }

        let inSpace = try converted(image, by: space.encoded, from: WorkingSpace.encoded, to: nil, compositing)
        let mapped = try lookUp(inSpace, table: table, amount: 1, linear: 0, library: library)
        let looked = try converted(mapped, by: space.working, from: nil, to: WorkingSpace.encoded, compositing)

        return amount < 1 ? try color("filterMix", image, [looked, amount], library) : looked
    }

    private func lookUp(
        _ image: CIImage,
        table: LookUpTable,
        amount: Double,
        linear: Double,
        library: KernelLibrary
    ) throws -> CIImage {
        let name = "filterLookUp"
        let kernel = try library.kernel(named: name)
        let tableExtent = table.image.extent
        let arguments: [Any] = [image, table.image, Double(table.size), table.domainMin, table.domainMax, amount, linear]
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

    // The image's colours converted pixel by pixel, unpremultiplied, by `conversion` (`convertColors(by:)`): read as
    // the values of colour space `source`, or as they are where it is nil, and taken as the values of `target`, or as
    // they are. The image is computed by the context of `compositing`'s form.
    private func converted(
        _ image: CIImage,
        by conversion: (RGB) -> RGB,
        from source: CGColorSpace?,
        to target: CGColorSpace?,
        _ compositing: Compositing
    ) throws -> CIImage {
        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)
        let rowBytes = width * 4 * MemoryLayout<Float>.size
        var pixels = [Float](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else { return }

            WorkingSpace.context(of: compositing).render(
                image,
                toBitmap: pointer,
                rowBytes: rowBytes,
                bounds: extent,
                format: .RGBAf,
                colorSpace: source
            )
        }
        pixels.withUnsafeMutableBufferPointer { $0.convertColors(by: conversion) }

        return CIImage(
            bitmapData: pixels.withUnsafeBufferPointer { Data(buffer: $0) },
            bytesPerRow: rowBytes,
            size: extent.size,
            format: .RGBAf,
            colorSpace: target
        )
        .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    // The image displaced by `map` laid over `frame`, `amount` and `offset` in the image's pixels, `offset` with y
    // pointing down. A pixel reads the image at most `amount` from its centre on each axis and the map anywhere.
    private func displaced(
        _ image: CIImage,
        by map: CGImage,
        amount: Double,
        offset: Point,
        frame: CGRect,
        library: KernelLibrary
    ) throws -> CIImage {
        let name = "filterDisplace"
        let kernel = try library.kernel(named: name)
        let values = CIImage(cgImage: map, options: [.colorSpace: NSNull()]).samplingNearest()
        let extent = image.extent
        let mapExtent = values.extent
        let arguments: [Any] = [
            image.samplingNearest(),
            values,
            CIVector(x: mapExtent.width, y: mapExtent.height),
            CIVector(x: frame.minX, y: frame.maxY, z: frame.width, w: frame.height),
            CIVector(x: offset.x, y: offset.y),
            amount,
            CIVector(x: extent.minX, y: extent.minY, z: extent.width, w: extent.height)
        ]
        guard let result = kernel.apply(
            extent: extent,
            roiCallback: { index, rect in
                index == 0 ? rect.insetBy(dx: -(amount + 1), dy: -(amount + 1)).intersection(extent) : mapExtent
            },
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
