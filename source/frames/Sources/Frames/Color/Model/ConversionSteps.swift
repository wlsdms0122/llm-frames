//
//  ConversionSteps.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A conversion to working values as the steps it runs on each unpremultiplied pixel, for a converter that runs them
// outside these formulas, on a GPU.
package enum ConversionSteps: Sendable {
    // The working value is the encoded value.
    case identity
    // Each channel decoded by `decodeTable`, the linear values taken to linear sRGB by `toLinearSRGB`, and encoded by
    // the sRGB transfer: an SDR space of the table other than `srgb`, and a video's SDR transfer and primaries.
    case decodeMatrixEncode(decodeTable: TransferDecodeTable, toLinearSRGB: ColorMatrix)
    // Steps only the formulas run: HDR light and its tone mapping, and an ICC profile's tone curves.
    case formulas
}
