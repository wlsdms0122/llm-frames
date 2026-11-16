//
//  LineBreakClass.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The line breaking classes of UAX #14, named in full, as resolve tells them from a scalar. Classes UAX #14 resolves
// to others before any rule applies come back resolved: ambiguous, unknown, surrogate, complex context, Hebrew letter
// and contingent break as alphabetic, conditional Japanese starter as nonstarter, and emoji base as ideographic.
enum LineBreakClass: Equatable, Sendable {
    case mandatoryBreak
    case carriageReturn
    case lineFeed
    case nextLine
    case space
    case zeroWidthSpace
    case zeroWidthJoiner
    case combiningMark
    case wordJoiner
    case glue
    case breakAfter
    case breakBefore
    case breakBoth
    case hyphen
    case closePunctuation
    case closeParenthesis
    case exclamation
    case inseparable
    case nonstarter
    case openPunctuation
    case quotation
    case infixSeparator
    case numeric
    case postfixNumeric
    case prefixNumeric
    case symbol
    case alphabetic
    case ideographic
    case emojiModifier
    case regionalIndicator
    case leadingJamo
    case vowelJamo
    case trailingJamo
    case twoJamoSyllable
    case threeJamoSyllable

    // MARK: - Property
    private static let listed: [UInt32: LineBreakClass] = {
        var table: [UInt32: LineBreakClass] = [:]
        let entries: [(LineBreakClass, [UInt32])] = [
            (.mandatoryBreak, [0x0B, 0x0C, 0x2028, 0x2029]),
            (.carriageReturn, [0x0D]),
            (.lineFeed, [0x0A]),
            (.nextLine, [0x85]),
            (.space, [0x20]),
            (.zeroWidthSpace, [0x200B]),
            (.zeroWidthJoiner, [0x200D]),
            (.wordJoiner, [0x2060, 0xFEFF]),
            (.glue, [0xA0, 0x034F, 0x2007, 0x2011, 0x202F]),
            (.breakAfter, [0x09, 0x7C, 0xAD, 0x058A, 0x05BE, 0x1680, 0x2010, 0x2012, 0x2013, 0x205F, 0x3000]
                + Array(0x2000...0x2006) + Array(0x2008...0x200A)),
            (.breakBefore, [0xB4, 0x02C8, 0x02CC, 0x02DF]),
            (.breakBoth, [0x2014]),
            (.hyphen, [0x2D]),
            (.closePunctuation, [
                0x7D, 0x0F3B, 0x0F3D, 0x2046, 0x207E, 0x208E, 0x2309, 0x230B, 0x232A, 0x3001, 0x3002, 0x3009, 0x300B,
                0x300D, 0x300F, 0x3011, 0x3015, 0x3017, 0x3019, 0x301B, 0x301E, 0x301F, 0xFE11, 0xFE12, 0xFE50,
                0xFE52, 0xFF09, 0xFF0C, 0xFF0E, 0xFF3D, 0xFF5D, 0xFF60, 0xFF61, 0xFF63, 0xFF64
            ]),
            (.closeParenthesis, [0x29, 0x5D]),
            (.exclamation, [0x21, 0x3F, 0x05C6, 0x061F, 0x06D4, 0x07F9, 0x0F0D, 0xFE15, 0xFE16, 0xFF01, 0xFF1F]),
            (.inseparable, [0x2024, 0x2025, 0x2026, 0xFE19]),
            (.nonstarter, [
                0x17D6, 0x203C, 0x203D, 0x2047, 0x2048, 0x2049, 0x3005, 0x301C, 0x303B, 0x303C, 0x309B, 0x309C,
                0x309D, 0x309E, 0x30A0, 0x30FB, 0x30FC, 0x30FD, 0x30FE, 0xA015, 0xFE54, 0xFE55, 0xFF1A, 0xFF1B,
                0xFF65, 0xFF9E, 0xFF9F,
                0x3041, 0x3043, 0x3045, 0x3047, 0x3049, 0x3063, 0x3083, 0x3085, 0x3087, 0x308E, 0x3095, 0x3096,
                0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30C3, 0x30E3, 0x30E5, 0x30E7, 0x30EE, 0x30F5, 0x30F6
            ] + Array(0x31F0...0x31FF) + Array(0xFF67...0xFF70)),
            (.openPunctuation, [
                0x28, 0x5B, 0x7B, 0xA1, 0xBF, 0x0F3A, 0x0F3C, 0x201A, 0x201E, 0x2045, 0x207D, 0x208D, 0x2308,
                0x230A, 0x2329, 0x3008, 0x300A, 0x300C, 0x300E, 0x3010, 0x3014, 0x3016, 0x3018, 0x301A, 0x301D,
                0xFE59, 0xFE5B, 0xFE5D, 0xFF08, 0xFF3B, 0xFF5B, 0xFF5F, 0xFF62
            ]),
            (.quotation, [0x22, 0x27, 0xAB, 0xBB, 0x2018, 0x2019, 0x201B, 0x201C, 0x201D, 0x201F, 0x2039, 0x203A]),
            (.infixSeparator, [0x2C, 0x2E, 0x3A, 0x3B, 0x037E, 0x0589, 0x060C, 0x060D, 0x2044, 0xFE10, 0xFE13, 0xFE14]),
            (.postfixNumeric, [
                0x25, 0xA2, 0xB0, 0x060B, 0x066A, 0x2030, 0x2031, 0x2032, 0x2033, 0x2034, 0x2035, 0x2036, 0x2037,
                0x20A7, 0x2103, 0x2109, 0xFDFC, 0xFE6A, 0xFF05, 0xFFE0
            ]),
            (.prefixNumeric, [
                0x24, 0x2B, 0x5C, 0xA3, 0xA4, 0xA5, 0xB1, 0x2116, 0x2212, 0x2213, 0xFE69, 0xFF04, 0xFFE1, 0xFFE5,
                0xFFE6
            ] + Array(0x20A0...0x20A6) + Array(0x20A8...0x20CF)),
            (.symbol, [0x2F])
        ]
        for (lineBreakClass, scalars) in entries {
            for scalar in scalars {
                table[scalar] = lineBreakClass
            }
        }

        return table
    }()

    private static let ideographicRanges: [ClosedRange<UInt32>] = [
        0x2E80...0x2FFF, 0x3003...0x3004, 0x3006...0x3007, 0x3012...0x3013, 0x3020...0x3029, 0x3030...0x303A,
        0x303D...0x303F, 0x3040...0x30FF, 0x3100...0x31EF, 0x3200...0x4DBF, 0x4E00...0x9FFF, 0xA000...0xA4CF,
        0xF900...0xFAFF, 0xFE30...0xFE4F, 0xFF01...0xFF60, 0x1F000...0x1F3FA, 0x1F400...0x1FAFF,
        0x20000...0x3FFFD
    ]

    // MARK: - Initializer
    init(_ scalar: Unicode.Scalar) {
        let value = scalar.value
        if let listed = Self.listed[value] {
            self = listed
        } else if let jamo = Self.hangul(value) {
            self = jamo
        } else if (0x1F1E6...0x1F1FF).contains(value) {
            self = .regionalIndicator
        } else if (0x1F3FB...0x1F3FF).contains(value) {
            self = .emojiModifier
        } else if Self.ideographicRanges.contains(where: { $0.contains(value) }) {
            self = .ideographic
        } else {
            self = Self.byCategory(scalar)
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func hangul(_ value: UInt32) -> LineBreakClass? {
        switch value {
        case 0x1100...0x115F, 0xA960...0xA97C:
            .leadingJamo

        case 0x1160...0x11A7, 0xD7B0...0xD7C6:
            .vowelJamo

        case 0x11A8...0x11FF, 0xD7CB...0xD7FB:
            .trailingJamo

        case 0xAC00...0xD7A3:
            (value - 0xAC00) % 28 == 0 ? .twoJamoSyllable : .threeJamoSyllable

        default:
            nil
        }
    }

    private static func byCategory(_ scalar: Unicode.Scalar) -> LineBreakClass {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark, .control:
            .combiningMark

        case .decimalNumber:
            .numeric

        default:
            .alphabetic
        }
    }
}
