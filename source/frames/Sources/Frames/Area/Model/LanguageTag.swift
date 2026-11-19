//
//  LanguageTag.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A recognition language, a well-formed BCP 47 tag (RFC 5646 `langtag` or `privateuse`) as it was written, which the
// OCR provider matches against what it recognises. The irregular grandfathered tags (`i-klingon`) are not well-formed
// by that grammar and are not taken.
package struct LanguageTag: Equatable, Sendable {
    // MARK: - Property
    package let text: String

    // MARK: - Initializer
    package init?(_ text: String) {
        let subtags = text.lowercased().split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard subtags.allSatisfy({ (1...8).contains($0.count) && $0.allSatisfy(Self.isAlphanumeric) }),
            Self.isWellFormed(subtags)
        else {
            return nil
        }

        self.text = text
    }

    // MARK: - Public
    // MARK: - Private
    // language ["-" script] ["-" region] *("-" variant) *("-" extension) ["-" privateuse], or privateuse alone.
    private static func isWellFormed(_ subtags: [String]) -> Bool {
        guard subtags.first != "x" else { return isPrivateUse(subtags[...]) }
        guard let language = subtags.first, (2...8).contains(language.count), language.allSatisfy(isLetter) else {
            return false
        }

        var index = 1
        // A language of two or three letters takes up to three extended language subtags of three letters.
        var extendedLanguages = 0
        while language.count <= 3, extendedLanguages < 3, index < subtags.count, isLetters(subtags[index], count: 3) {
            index += 1
            extendedLanguages += 1
        }
        if index < subtags.count, isLetters(subtags[index], count: 4) {
            index += 1
        }
        if index < subtags.count, isRegion(subtags[index]) {
            index += 1
        }
        while index < subtags.count, isVariant(subtags[index]) {
            index += 1
        }
        // An extension is a singleton other than `x` followed by at least one subtag of two to eight characters.
        while index < subtags.count, subtags[index].count == 1, subtags[index] != "x" {
            let start = index + 1
            index = start
            while index < subtags.count, subtags[index].count >= 2 {
                index += 1
            }
            guard index > start else { return false }
        }
        guard index < subtags.count else { return true }

        return isPrivateUse(subtags[index...])
    }

    private static func isPrivateUse(_ subtags: ArraySlice<String>) -> Bool {
        subtags.first == "x" && subtags.count > 1
    }

    private static func isLetters(
        _ subtag: String,
        count: Int
    ) -> Bool {
        subtag.count == count && subtag.allSatisfy(isLetter)
    }

    private static func isRegion(_ subtag: String) -> Bool {
        isLetters(subtag, count: 2) || subtag.count == 3 && subtag.allSatisfy(isDigit)
    }

    private static func isVariant(_ subtag: String) -> Bool {
        subtag.count >= 5 || subtag.count == 4 && subtag.first.map(isDigit) == true
    }

    private static func isAlphanumeric(_ character: Character) -> Bool {
        isLetter(character) || isDigit(character)
    }

    private static func isLetter(_ character: Character) -> Bool {
        character.isASCII && character.isLetter
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }
}
