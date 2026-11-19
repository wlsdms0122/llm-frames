//
//  ResolvedFilterOperation+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filter operation as resolve leaves it, a LUT's file pinned and a bloom's colour, already a value, read as one.
extension ResolvedFilterOperation {
    // MARK: - Property
    // MARK: - Initializer
    init(
        operation: FilterOperation,
        hashes: any FileHashProvider
    ) throws {
        switch operation {
        case let .exposure(ev):
            self = .exposure(ev: ev)

        case let .contrast(amount):
            self = .contrast(amount: amount)

        case let .saturation(amount):
            self = .saturation(amount: amount)

        case let .temperature(kelvin):
            self = .temperature(kelvin: kelvin)

        case let .hue(degrees):
            self = .hue(degrees: degrees)

        case let .sepia(amount):
            self = .sepia(amount: amount)

        case let .levels(input, output):
            self = .levels(input: input, output: output)

        case let .lut(file, amount, space):
            self = .lut(file: try PinnedFile(path: file, hashes: hashes), amount: amount, space: space)

        case let .blur(radius):
            self = .blur(radius: radius)

        case let .sharpen(amount, radius):
            self = .sharpen(amount: amount, radius: radius)

        case let .bloom(amount, radius, color):
            self = .bloom(amount: amount, radius: radius, color: color.map(Color.init(written:)))

        case let .vignette(amount, radius):
            self = .vignette(amount: amount, radius: radius)

        case let .pixelate(size):
            self = .pixelate(size: size)

        case let .grain(amount, size):
            self = .grain(amount: amount, size: size)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
