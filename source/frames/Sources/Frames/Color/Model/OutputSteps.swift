//
//  OutputSteps.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The conversion of working values to an output's encoded values as the steps it runs on each unpremultiplied pixel,
// for a converter that runs them outside these formulas, on a GPU.
package enum OutputSteps: Sendable {
    // Each channel of the working value clipped to 0 to 1: `srgb`.
    case clip
    // Each channel decoded by the sRGB transfer, the linear values taken to the space's primaries by `fromLinearSRGB`,
    // clipped to 0 to 1 and encoded by `transfer`: an SDR space of the table other than `srgb`.
    case decodeMatrixClipEncode(fromLinearSRGB: ColorMatrix, transfer: TransferFunction)
    // Steps only the formulas run: HDR light clipped to the peak and encoded by PQ or HLG.
    case formulas
}
