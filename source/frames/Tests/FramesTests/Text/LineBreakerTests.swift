//
//  LineBreakerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("LineBreaker Tests")
struct LineBreakerTests {
    // MARK: - Property
    private static let pieces: [(String, [String])] = [
        ("hello world", ["hello ", "world"]),
        ("hello   world", ["hello   ", "world"]),
        ("Hello, world!", ["Hello, ", "world!"]),
        ("well-known", ["well-", "known"]),
        ("is -5 or $100.50 or 100%", ["is ", "-5 ", "or ", "$100.50 ", "or ", "100%"]),
        ("and/or", ["and/", "or"]),
        ("a (b) c", ["a ", "(b) ", "c"]),
        (#"say "hi" now"#, ["say ", #""hi" "#, "now"]),
        ("a\u{00A0}b c", ["a\u{00A0}b ", "c"]),
        ("a\u{200B}b", ["a\u{200B}", "b"]),
        ("a\u{2060}b", ["a\u{2060}b"]),
        ("e\u{0301} f", ["e\u{0301} ", "f"]),
        ("漢字。", ["漢", "字。"]),
        ("ちょっと", ["ちょっ", "と"]),
        ("결제 하기", ["결", "제 ", "하", "기"]),
        ("\u{1100}\u{1161}\u{11A8}", ["\u{1100}\u{1161}\u{11A8}"]),
        ("👩\u{200D}💻👩\u{200D}💻", ["👩\u{200D}💻", "👩\u{200D}💻"]),
        ("👍\u{1F3FD}👍", ["👍\u{1F3FD}", "👍"]),
        ("🇰🇷🇯🇵🇫", ["🇰🇷", "🇯🇵", "🇫"]),
        ("word\u{2014}word", ["word", "\u{2014}", "word"]),
        ("1.5", ["1.5"])
    ]
    // Words as keep-all keeps them: breaks between letters, numbers, ideographs and Hangul fall inside a word.
    private static let words: [(String, [String])] = [
        ("결제하기 버튼을 누르세요", ["결제하기 ", "버튼을 ", "누르세요"]),
        ("iPhone에서", ["iPhone에서"]),
        ("1,000원", ["1,000원"]),
        ("결제(하기)", ["결제", "(하기)"]),
        ("결제-하기", ["결제-", "하기"]),
        ("漢字。", ["漢字。"]),
        ("hello world", ["hello ", "world"])
    ]

    private let sut = LineBreaker()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "lines may break only where UAX #14 allows",
        arguments: pieces
    )
    func breaksWhereAllowed(
        text: String,
        pieces: [String]
    ) {
        // Given
        let scalars = Array(text.unicodeScalars)

        // When
        let breaks = sut.breaks(in: scalars)

        // Then
        #expect(split(scalars, at: breaks) == pieces)
        #expect(!breaks.contains(.mandatory))
    }

    @Test(
        "a break UAX #14 allows between two letter units is inside a word, as keep-all sees one",
        arguments: words
    )
    func keepsWords(
        text: String,
        words: [String]
    ) {
        // Given
        let scalars = Array(text.unicodeScalars)

        // When
        let breaks = sut.breaks(in: scalars)

        // Then
        #expect(split(scalars, at: breaks.map { $0 == .insideWord ? .prohibited : $0 }) == words)
    }

    @Test(
        "a line must break after a hard break, and never between CR and LF",
        arguments: [
            ("a\nb", [LineBreak.prohibited, .prohibited, .mandatory]),
            ("a\r\nb", [.prohibited, .prohibited, .prohibited, .mandatory]),
            ("a\rb", [.prohibited, .prohibited, .mandatory]),
            ("a\u{2028}b", [.prohibited, .prohibited, .mandatory]),
            ("a \nb", [.prohibited, .prohibited, .prohibited, .mandatory])
        ]
    )
    func breaksAfterHardBreak(
        text: String,
        breaks: [LineBreak]
    ) {
        // Given
        let scalars = Array(text.unicodeScalars)

        // When
        let found = sut.breaks(in: scalars)

        // Then
        #expect(found == breaks)
    }

    // MARK: - Private
    private func split(
        _ scalars: [Unicode.Scalar],
        at breaks: [LineBreak]
    ) -> [String] {
        scalars.indices.reduce(into: [String]()) { pieces, index in
            if index == 0 || breaks[index] != .prohibited {
                pieces.append("")
            }
            pieces[pieces.count - 1].unicodeScalars.append(scalars[index])
        }
    }
}
