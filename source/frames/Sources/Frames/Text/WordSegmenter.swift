//
//  WordSegmenter.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Splits text at the word boundaries of UAX #29's default rules, with no dictionary, so each ideograph is a word of its
// own and a run of letters of any alphabet, Hangul among them, is one. It reads grapheme clusters, which hold the
// marks and joiners the rules would keep with the character before them.
struct WordSegmenter: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // The pieces between boundaries, as ranges of `characters`, in order and covering them all.
    func segments(of characters: [Character]) -> [Range<Int>] {
        let properties = characters.map(WordBreakProperty.init)
        // A format character takes no part in the rules and stays with the character before it.
        let ruled = properties.indices.filter { $0 == 0 || properties[$0] != .format }
        let property = { (position: Int) -> WordBreakProperty? in
            ruled.indices.contains(position) ? properties[ruled[position]] : nil
        }

        var starts: [Int] = ruled.isEmpty ? [] : [0]
        for position in ruled.indices.dropFirst() {
            let isJoined = isJoined(
                before: property(position - 2),
                left: property(position - 1),
                right: property(position),
                after: property(position + 1)
            )
            if !isJoined {
                starts.append(ruled[position])
            }
        }

        return starts.indices.map { index in
            starts[index]..<(starts.indices.contains(index + 1) ? starts[index + 1] : characters.count)
        }
    }

    // MARK: - Private
    // Whether the rules keep `left` and `right` in one word, `before` and `after` the properties around them.
    private func isJoined(
        before: WordBreakProperty?,
        left: WordBreakProperty?,
        right: WordBreakProperty?,
        after: WordBreakProperty?
    ) -> Bool {
        guard let left, let right else { return false }

        let isWordPart = { (property: WordBreakProperty) in
            property.isLetter || property == .numeric || property == .katakana
        }

        switch (left, right) {
        case (.space, .space):
            return true

        case (.hebrewLetter, .singleQuote):
            return true

        case let (left, right) where left.isLetter && right.isLetter:
            return true

        case let (left, right) where left.isLetter && right.isMidLetter:
            return after?.isLetter ?? false

        case let (left, right) where left.isMidLetter && right.isLetter:
            return before?.isLetter ?? false

        case (.hebrewLetter, .doubleQuote):
            return after == .hebrewLetter

        case (.doubleQuote, .hebrewLetter):
            return before == .hebrewLetter

        case (.numeric, .numeric):
            return true

        case let (left, .numeric) where left.isLetter:
            return true

        case let (.numeric, right) where right.isLetter:
            return true

        case let (.numeric, right) where right.isMidNumber:
            return after == .numeric

        case let (left, .numeric) where left.isMidNumber:
            return before == .numeric

        case (.katakana, .katakana):
            return true

        case let (left, .extendNumberLetter) where isWordPart(left) || left == .extendNumberLetter:
            return true

        case let (.extendNumberLetter, right) where isWordPart(right):
            return true

        default:
            return false
        }
    }
}
