//
//  WordBreakProperty.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The word break property of UAX #29 that its default rules read, told from a grapheme cluster by its first scalar, so
// the marks and joiners a cluster holds take its property. A format character outside a cluster is `format`, which the
// rules pass over. Letters of the scripts UAX #14 sets by dictionary (Thai, Lao, Myanmar, Khmer) are `other`, as
// UAX #29 leaves them, and so are ideographs and Hiragana, so each is a word of its own.
enum WordBreakProperty: Equatable, Sendable {
    case letter
    case hebrewLetter
    case katakana
    case numeric
    case singleQuote
    case doubleQuote
    case midLetter
    case midNumber
    case midNumberLetter
    case extendNumberLetter
    case space
    case format
    case other

    // MARK: - Property
    // A letter of either kind, which the letter rules join.
    var isLetter: Bool {
        self == .letter || self == .hebrewLetter
    }

    // What may sit between two letters, or two numbers, inside one word.
    var isMidLetter: Bool {
        self == .midLetter || self == .midNumberLetter || self == .singleQuote
    }

    var isMidNumber: Bool {
        self == .midNumber || self == .midNumberLetter || self == .singleQuote
    }

    private static let listed: [UInt32: WordBreakProperty] = {
        var table: [UInt32: WordBreakProperty] = [:]
        let entries: [(WordBreakProperty, [UInt32])] = [
            (.singleQuote, [0x27]),
            (.doubleQuote, [0x22]),
            (.midLetter, [0x3A, 0xB7, 0x0387, 0x055F, 0x05F4, 0x2027, 0xFE13, 0xFE55, 0xFF1A]),
            (.midNumber, [
                0x2C, 0x3B, 0x037E, 0x0589, 0x060C, 0x060D, 0x066C, 0x07F8, 0x2044, 0xFE10, 0xFE14, 0xFE50, 0xFE54,
                0xFF0C, 0xFF1B
            ]),
            (.midNumberLetter, [0x2E, 0x2018, 0x2019, 0x2024, 0xFE52, 0xFF07, 0xFF0E]),
            (.extendNumberLetter, [0x202F])
        ]
        for (property, scalars) in entries {
            for scalar in scalars {
                table[scalar] = property
            }
        }

        return table
    }()

    private static let katakanaRanges: [ClosedRange<UInt32>] = [
        0x3031...0x3035, 0x309B...0x309C, 0x30A0...0x30FA, 0x30FC...0x30FF, 0x31F0...0x31FF, 0x32D0...0x32FE,
        0x3300...0x3357, 0xFF66...0xFF9D, 0x1B000...0x1B000
    ]

    private static let hebrewRanges: [ClosedRange<UInt32>] = [
        0x05D0...0x05EA, 0x05EF...0x05F2, 0xFB1D...0xFB1D, 0xFB1F...0xFB28, 0xFB2A...0xFB4F
    ]

    // Hiragana and the scripts UAX #14 gives the complex context class, whose letters UAX #29 does not join.
    private static let unjoinedRanges: [ClosedRange<UInt32>] = [
        0x3040...0x309F, 0x0E00...0x0EFF, 0x1000...0x109F, 0x1780...0x17FF, 0x19E0...0x19FF, 0xAA60...0xAADF
    ]

    // MARK: - Initializer
    init(_ character: Character) {
        guard let scalar = character.unicodeScalars.first else {
            self = .other
            return
        }

        let value = scalar.value
        let properties = scalar.properties
        if let listed = Self.listed[value] {
            self = listed
        } else if Self.katakanaRanges.contains(where: { $0.contains(value) }) {
            self = .katakana
        } else if Self.hebrewRanges.contains(where: { $0.contains(value) }) {
            self = .hebrewLetter
        } else {
            switch properties.generalCategory {
            case .decimalNumber:
                self = .numeric

            case .connectorPunctuation:
                self = .extendNumberLetter

            case .spaceSeparator:
                // No-break spaces glue the words beside them in UAX #14 and are no word space in UAX #29.
                self = [0xA0, 0x2007].contains(value) ? .other : .space

            case .format:
                self = .format

            default:
                let isUnjoined = Self.unjoinedRanges.contains { $0.contains(value) }
                self = properties.isAlphabetic && !properties.isIdeographic && !isUnjoined ? .letter : .other
            }
        }
    }

    // MARK: - Public
    // MARK: - Private
}
