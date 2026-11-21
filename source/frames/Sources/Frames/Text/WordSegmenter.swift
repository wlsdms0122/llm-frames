//
//  WordSegmenter.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Splits text at the word boundaries of UAX #29's default rules, with no dictionary, so each ideograph is a word of its
// own and a run of letters of any alphabet, Hangul among them, is one. It reads grapheme clusters, which hold the
// marks and joiners the rules would keep with the character before them, and finds the words among the pieces.
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

    // A piece between word boundaries that holds a letter, a digit or an ideograph is a word. A piece of punctuation
    // or symbols, general categories P and S, with the pieces of them it touches, joins the word it touches, the one
    // before it when it touches two, and is a word of its own when it touches none. A default ignorable character takes
    // no part, and a piece of other characters is in no word. Each word is the range of `characters` from its first
    // piece to its last, in order.
    func words(of characters: [Character]) -> [Range<Int>] {
        var groups: [[Int]] = []
        var punctuation: [Int] = []
        var isAfterWord = false
        for segment in segments(of: characters) {
            let marks = characters[segment].filter { !isIgnorable($0) }
            if marks.isEmpty {
                continue
            } else if marks.allSatisfy(isSpace) {
                if !punctuation.isEmpty {
                    groups.append(punctuation)
                    punctuation = []
                }
                isAfterWord = false
            } else if marks.contains(where: isWordCharacter) {
                groups.append(punctuation + Array(segment))
                punctuation = []
                isAfterWord = true
            } else if marks.allSatisfy(isPunctuation) {
                if isAfterWord {
                    groups[groups.count - 1] += Array(segment)
                } else {
                    punctuation += Array(segment)
                }
            }
        }
        if !punctuation.isEmpty {
            groups.append(punctuation)
        }

        return groups.compactMap { group in group.first.map { $0..<(group[group.count - 1] + 1) } }
    }

    // MARK: - Private
    // A space is a cluster whose first scalar is `White_Space`.
    private func isSpace(_ character: Character) -> Bool {
        character.unicodeScalars.first?.properties.isWhitespace ?? false
    }

    private func isIgnorable(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(\.properties.isDefaultIgnorableCodePoint)
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.first.map { scalar in
            scalar.properties.isAlphabetic
                || scalar.properties.isIdeographic
                || scalar.properties.generalCategory == .decimalNumber
        } ?? false
    }

    private func isPunctuation(_ character: Character) -> Bool {
        switch character.unicodeScalars.first?.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation, .initialPunctuation,
            .finalPunctuation, .otherPunctuation, .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            true

        default:
            false
        }
    }

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
