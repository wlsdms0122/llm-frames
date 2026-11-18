//
//  Array+LanguageTag.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Recognition languages written as BCP 47 tags separated by commas, in order of preference, as `en-US,ko-KR`. Nil
// when any of them is not a well-formed tag.
extension Array where Element == LanguageTag {
    // MARK: - Property
    // MARK: - Initializer
    package init?(commaSeparated text: String) {
        let tags = text.split(separator: ",", omittingEmptySubsequences: false).map { LanguageTag(String($0)) }
        guard !tags.contains(nil) else { return nil }

        self = tags.compactMap(\.self)
    }

    // MARK: - Public
    // MARK: - Private
}
