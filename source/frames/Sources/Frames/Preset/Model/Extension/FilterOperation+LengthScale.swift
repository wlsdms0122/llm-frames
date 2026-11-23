//
//  FilterOperation+LengthScale.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filter operation with its theme lengths (a blur, sharpen or bloom radius, a displace amount and offset, a pixelate or
// grain size) multiplied by the length scale of the place it is drawn. A vignette's radius is a fraction and stays.
extension FilterOperation {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func scaled(by scale: Double) -> FilterOperation {
        switch self {
        case let .blur(radius):
            .blur(radius: radius * scale)

        case let .sharpen(amount, radius):
            .sharpen(amount: amount, radius: radius * scale)

        case let .bloom(amount, radius, color):
            .bloom(amount: amount, radius: radius * scale, color: color)

        case let .displace(file, amount, offset):
            .displace(file: file, amount: amount * scale, offset: Point(x: offset.x * scale, y: offset.y * scale))

        case let .pixelate(size):
            .pixelate(size: size * scale)

        case let .grain(amount, size):
            .grain(amount: amount, size: size * scale)

        case .exposure, .contrast, .saturation, .temperature, .hue, .sepia, .levels, .lut, .vignette:
            self
        }
    }

    // MARK: - Private
}
