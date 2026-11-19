//
//  ResolvedFilterOperation.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filter operation as resolved: its lengths scaled into the pixels it is drawn in, a LUT's file pinned with the
// colour space it is built for, and a bloom's colour as a value.
package enum ResolvedFilterOperation: Equatable, Sendable {
    case exposure(ev: Double)
    case contrast(amount: Double)
    case saturation(amount: Double)
    case temperature(kelvin: Double)
    case hue(degrees: Double)
    case sepia(amount: Double)
    case levels(input: [Double], output: [Double])
    case lut(file: PinnedFile, amount: Double, space: ColorSpace = .srgb)
    case blur(radius: Double)
    case sharpen(amount: Double, radius: Double)
    case bloom(amount: Double, radius: Double, color: Color?)
    case vignette(amount: Double, radius: Double)
    case pixelate(size: Double)
    case grain(amount: Double, size: Double)
}
