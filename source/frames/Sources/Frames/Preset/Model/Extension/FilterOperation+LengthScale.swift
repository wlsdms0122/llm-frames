//
//  FilterOperation+LengthScale.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filter operation with its theme lengths (a blur, sharpen or bloom radius, a pixelate or grain size) multiplied by
// the length scale of the place it is drawn. A vignette's radius is a fraction and stays.
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

        case let .pixelate(size):
            .pixelate(size: size * scale)

        case let .grain(amount, size):
            .grain(amount: amount, size: size * scale)

        default:
            self
        }
    }

    // MARK: - Private
}
