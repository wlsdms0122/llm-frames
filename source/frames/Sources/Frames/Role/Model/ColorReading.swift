//
//  ColorReading.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// How a decoder takes a file's pictures to working values (FRAMES-26 Media): by the fixed formulas, from the colour
// space of the table its tags name, nil for tags outside the table, or only by the platform's own colour management,
// for an image whose ICC profile is LUT-based or a video with code points no formula defines.
package enum ColorReading: Equatable, Sendable {
    case formulas(ColorSpace?)
    case platform
}
