//
//  FilterOperation.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum FilterOperation: Equatable, Sendable {
    case exposure(ev: Double)
    case contrast(amount: Double)
    case saturation(amount: Double)
    case temperature(kelvin: Double)
    case hue(degrees: Double)
    case sepia(amount: Double)
    case levels(input: [Double], output: [Double])
    case lut(file: String, amount: Double, space: LookUpTableSpace = .srgb)
    case blur(radius: Double)
    case sharpen(amount: Double, radius: Double)
    case bloom(amount: Double, radius: Double, color: String?)
    case vignette(amount: Double, radius: Double)
    case pixelate(size: Double)
    case grain(amount: Double, size: Double)
}
