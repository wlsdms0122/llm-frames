//
//  VerticalOrientation.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// The orientation of a character in vertical text by UAX #50, its Vertical_Orientation values named in full, as `init`
// tells them from a scalar. Swift gives no Vertical_Orientation, so the table is the Unicode 17.0.0 data of
// VerticalOrientation.txt, which `source/vertical-data.py` writes, unassigned scalars taking the defaults it gives
// their blocks.
enum VerticalOrientation: Equatable, Sendable {
    case upright
    case rotated
    case transformedUpright
    case transformedRotated

    // MARK: - Property
    // The first scalar of each stretch of scalars that share an orientation, in order, and the orientation of each
    // stretch.
    private static let starts: [UInt32] = [
        0x0000, 0x00A7, 0x00A8, 0x00A9, 0x00AA, 0x00AE, 0x00AF, 0x00B1, 0x00B2, 0x00BC, 0x00BF, 0x00D7, 0x00D8, 0x00F7,
        0x00F8, 0x02EA, 0x02EC, 0x1100, 0x1200, 0x1401, 0x1680, 0x18B0, 0x1900, 0x2016, 0x2017, 0x2018, 0x201A, 0x201C,
        0x201E, 0x2020, 0x2022, 0x2030, 0x2032, 0x203B, 0x203D, 0x2042, 0x2043, 0x2047, 0x204A, 0x2051, 0x2052, 0x2065,
        0x2066, 0x20DD, 0x20E1, 0x20E2, 0x20E5, 0x2100, 0x2102, 0x2103, 0x210A, 0x210F, 0x2110, 0x2113, 0x2115, 0x2116,
        0x2118, 0x211E, 0x2124, 0x2125, 0x2126, 0x2127, 0x2128, 0x2129, 0x212A, 0x212E, 0x212F, 0x2135, 0x2140, 0x2145,
        0x214B, 0x214C, 0x214E, 0x214F, 0x218A, 0x218C, 0x2190, 0x221E, 0x221F, 0x2234, 0x2236, 0x2300, 0x2308, 0x230C,
        0x2320, 0x2324, 0x2329, 0x232B, 0x232C, 0x237D, 0x239B, 0x23BE, 0x23CE, 0x23CF, 0x23D0, 0x23D1, 0x23DC, 0x23E2,
        0x2423, 0x2424, 0x2500, 0x25A0, 0x261A, 0x2620, 0x2768, 0x2776, 0x2794, 0x2B12, 0x2B30, 0x2B50, 0x2B5A, 0x2B97,
        0x2B98, 0x2BB8, 0x2BD2, 0x2BD3, 0x2BEC, 0x2BF0, 0x2C00, 0x2E50, 0x2E52, 0x2E80, 0x3001, 0x3003, 0x3008, 0x3012,
        0x3014, 0x3020, 0x3030, 0x3031, 0x3041, 0x3042, 0x3043, 0x3044, 0x3045, 0x3046, 0x3047, 0x3048, 0x3049, 0x304A,
        0x3063, 0x3064, 0x3083, 0x3084, 0x3085, 0x3086, 0x3087, 0x3088, 0x308E, 0x308F, 0x3095, 0x3097, 0x309B, 0x309D,
        0x30A0, 0x30A1, 0x30A2, 0x30A3, 0x30A4, 0x30A5, 0x30A6, 0x30A7, 0x30A8, 0x30A9, 0x30AA, 0x30C3, 0x30C4, 0x30E3,
        0x30E4, 0x30E5, 0x30E6, 0x30E7, 0x30E8, 0x30EE, 0x30EF, 0x30F5, 0x30F7, 0x30FC, 0x30FD, 0x3127, 0x3128, 0x31B4,
        0x31B8, 0x31BB, 0x31BC, 0x31F0, 0x3200, 0x32FF, 0x3358, 0x337B, 0x3380, 0xA4D0, 0xA960, 0xA980, 0xAC00, 0xD800,
        0xE000, 0xFB00, 0xFE10, 0xFE20, 0xFE30, 0xFE49, 0xFE50, 0xFE53, 0xFE58, 0xFE59, 0xFE5F, 0xFE63, 0xFE67, 0xFE70,
        0xFF01, 0xFF02, 0xFF08, 0xFF0A, 0xFF0C, 0xFF0D, 0xFF0E, 0xFF0F, 0xFF1A, 0xFF1C, 0xFF1F, 0xFF20, 0xFF3B, 0xFF3C,
        0xFF3D, 0xFF3E, 0xFF3F, 0xFF40, 0xFF5B, 0xFF61, 0xFFE0, 0xFFE3, 0xFFE4, 0xFFE8, 0xFFF0, 0xFFF9, 0xFFFC, 0xFFFE,
        0x10980, 0x109A0, 0x11580, 0x11600, 0x11A00, 0x11AC0, 0x13000, 0x14680, 0x16FE0, 0x18E00, 0x1AFF0, 0x1B132,
        0x1B133, 0x1B150, 0x1B153, 0x1B155, 0x1B156, 0x1B164, 0x1B168, 0x1B300, 0x1CEC0, 0x1CFD0, 0x1D000, 0x1D200,
        0x1D2E0, 0x1D380, 0x1D800, 0x1DAB0, 0x1F000, 0x1F200, 0x1F202, 0x1F800, 0x1F900, 0x1FB00, 0x20000, 0x2FFFE,
        0x30000, 0x3FFFE, 0xF0000, 0xFFFFE, 0x100000, 0x10FFFE
    ]
    private static let orientations: [VerticalOrientation] = [
        .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .rotated, .upright, .rotated, .transformedRotated, .rotated, .transformedRotated, .rotated, .upright, .rotated,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .transformedRotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .rotated, .upright, .rotated, .upright, .transformedUpright, .upright, .transformedRotated, .upright,
        .transformedRotated, .upright, .transformedRotated, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedRotated, .transformedUpright,
        .upright, .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedRotated, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .rotated, .upright, .rotated, .upright, .rotated,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .transformedUpright, .upright, .rotated,
        .transformedRotated, .upright, .rotated, .upright, .rotated, .transformedUpright, .upright,
        .transformedRotated, .upright, .transformedUpright, .rotated, .transformedUpright, .upright,
        .transformedRotated, .rotated, .transformedUpright, .upright, .transformedRotated, .upright,
        .transformedRotated, .upright, .transformedRotated, .upright, .transformedRotated, .rotated, .upright,
        .transformedRotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .transformedUpright, .upright,
        .transformedUpright, .upright, .transformedUpright, .upright, .transformedUpright, .upright, .rotated,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .transformedUpright,
        .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright, .rotated, .upright,
        .rotated
    ]

    // Whether a character of this orientation stands upright in a vertical line, as CSS `text-orientation: mixed` sets
    // it: every orientation but `rotated`, which is set turned 90 degrees clockwise.
    var isUpright: Bool {
        self != .rotated
    }

    // MARK: - Initializer
    init(_ scalar: Unicode.Scalar) {
        var low = 0
        var high = Self.starts.count
        while high - low > 1 {
            let middle = (low + high) / 2
            if Self.starts[middle] <= scalar.value {
                low = middle
            } else {
                high = middle
            }
        }

        self = Self.orientations[low]
    }

    // MARK: - Public
    // MARK: - Private
}
