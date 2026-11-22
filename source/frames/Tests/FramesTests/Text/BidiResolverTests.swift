//
//  BidiResolverTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import Testing

@testable import Frames

// The conformance files are a part of the Unicode ones `source/bidi-data.py` writes, each case one line resolved as one
// paragraph and one line of text. A level the files give as `x` is one rule X9 removes, which they leave out of the
// visual order.
@Suite("BidiResolver Tests")
struct BidiResolverTests {
    private struct ConformanceCase {
        let line: Int
        let scalars: [Unicode.Scalar]
        // nil for auto, which P2 and P3 resolve.
        let paragraphLevel: Int?
        let resolvedParagraphLevel: Int?
        let levels: [Int?]
        let order: [Int]
    }

    // MARK: - Property
    // A scalar of each class, none of them a bracket, for BidiTest.txt, which gives classes.
    private static let representatives: [String: Unicode.Scalar] = [
        "L": "a", "R": "\u{05D0}", "AL": "\u{0627}", "EN": "0", "ES": "+", "ET": "#", "AN": "\u{0660}", "CS": ",",
        "NSM": "\u{0300}", "BN": "\u{00AD}", "B": "\u{2029}", "S": "\t", "WS": " ", "ON": "!", "LRE": "\u{202A}",
        "LRO": "\u{202D}", "RLE": "\u{202B}", "RLO": "\u{202E}", "PDF": "\u{202C}", "LRI": "\u{2066}",
        "RLI": "\u{2067}", "FSI": "\u{2068}", "PDI": "\u{2069}"
    ]

    private let sut = BidiResolver()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "the paragraph level is that of the first strong character outside an isolate, in the first paragraph with one",
        arguments: [
            ("abc", 0),
            ("\u{05D0}bc", 1),
            ("12 \u{0627}", 1),
            ("\u{2067}\u{05D0}\u{2069}a", 0),
            ("12\n\u{05D0}", 1),
            ("12 !", nil)
        ] as [(String, Int?)]
    )
    func paragraphLevel(
        text: String,
        level: Int?
    ) {
        // Given
        let scalars = Array(text.unicodeScalars)

        // When
        let paragraphLevel = sut.paragraphLevel(of: scalars)

        // Then
        #expect(paragraphLevel == level)
    }

    @Test(
        "each scalar takes its embedding level, and one rule X9 removes takes the level of the scalar before it",
        arguments: [
            ("abc \u{05D0}\u{05D1}", 0, [0, 0, 0, 0, 1, 1]),
            ("\u{05D0} 12", 1, [1, 1, 2, 2]),
            ("a\u{202B}b\u{202C}c", 0, [0, 0, 2, 2, 0]),
            ("\u{00AD}a", 1, [1, 2]),
            ("\u{05D0}\na", 1, [1, 1, 2])
        ]
    )
    func levels(
        text: String,
        paragraphLevel: Int,
        levels: [Int]
    ) {
        // Given
        let scalars = Array(text.unicodeScalars)

        // When
        let resolved = sut.levels(of: scalars, paragraphLevel: paragraphLevel)

        // Then
        #expect(resolved == levels)
    }

    @Test("the spaces that end each line take the paragraph level")
    func lineLevels() {
        // Given
        let scalars = Array("a b ".unicodeScalars)
        let levels = sut.levels(of: scalars, paragraphLevel: 1)

        // When
        let lineLevels = sut.lineLevels(of: scalars, levels: levels, lines: [0..<2, 2..<4], paragraphLevel: 1)

        // Then
        #expect(levels == [2, 2, 2, 1])
        #expect(lineLevels == [2, 1, 2, 1])
    }

    @Test(
        "a line is reversed from its highest level down to its lowest odd one",
        arguments: [
            ([0, 0, 1, 1, 0], [0, 1, 3, 2, 4]),
            ([0, 1, 1, 2, 2, 1, 0], [0, 5, 3, 4, 2, 1, 6]),
            ([2, 2, 2], [0, 1, 2]),
            ([], [])
        ]
    )
    func visualOrder(
        levels: [Int],
        order: [Int]
    ) {
        // Given
        // When
        let visualOrder = BidiResolver.visualOrder(of: levels)

        // Then
        #expect(visualOrder == order)
    }

    @Test("every case of BidiCharacterTest.txt resolves as Unicode gives it")
    func bidiCharacterTest() throws {
        // Given
        let cases = try characterCases()

        // When
        let failed = cases.filter { !passes($0) }.map(\.line)

        // Then
        #expect(!cases.isEmpty)
        #expect(failed.isEmpty, "\(failed.count) of \(cases.count) cases fail, the first on lines \(failed.prefix(10))")
    }

    @Test("every case of BidiTest.txt resolves as Unicode gives it")
    func bidiTest() throws {
        // Given
        let cases = try classCases()

        // When
        let failed = cases.filter { !passes($0) }.map(\.line)

        // Then
        #expect(!cases.isEmpty)
        #expect(failed.isEmpty, "\(failed.count) of \(cases.count) cases fail, the first on lines \(failed.prefix(10))")
    }

    // MARK: - Private
    private func passes(_ conformanceCase: ConformanceCase) -> Bool {
        let scalars = conformanceCase.scalars
        let paragraphLevel = conformanceCase.paragraphLevel ?? sut.paragraphLevel(of: scalars) ?? 0
        let levels = sut.levels(of: scalars, paragraphLevel: paragraphLevel)
        let lineLevels = sut.lineLevels(
            of: scalars,
            levels: levels,
            lines: [0..<scalars.count],
            paragraphLevel: paragraphLevel
        )
        let order = BidiResolver.visualOrder(of: lineLevels).filter { conformanceCase.levels[$0] != nil }
        let isLevelsEqual = zip(lineLevels, conformanceCase.levels).allSatisfy { level, expected in
            expected.map { $0 == level } ?? true
        }

        let isParagraphLevelEqual = conformanceCase.resolvedParagraphLevel.map { $0 == paragraphLevel } ?? true

        return isParagraphLevelEqual && isLevelsEqual && order == conformanceCase.order
    }

    private func lines(of name: String) throws -> [(Int, String)] {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Resources"))

        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { ($0 + 1, String($1)) }
            .filter { !$1.isEmpty && !$1.hasPrefix("#") }
    }

    private func numbers(_ field: String) -> [Int?] {
        field.split(whereSeparator: \.isWhitespace).map { Int($0) }
    }

    private func characterCases() throws -> [ConformanceCase] {
        try lines(of: "BidiCharacterTest").map { line, text in
            let fields = text.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
            let direction = Int(fields[1]) ?? 0
            let values = fields[0].split(separator: " ").compactMap { UInt32($0, radix: 16) }

            return ConformanceCase(
                line: line,
                scalars: values.compactMap(Unicode.Scalar.init),
                paragraphLevel: direction == 2 ? nil : direction,
                resolvedParagraphLevel: Int(fields[2]),
                levels: numbers(fields[3]),
                order: numbers(fields[4]).compactMap(\.self)
            )
        }
    }

    private func classCases() throws -> [ConformanceCase] {
        var levels: [Int?] = []
        var order: [Int] = []
        var cases: [ConformanceCase] = []
        for (line, text) in try lines(of: "BidiTest") {
            let fields = text.split(separator: ":", maxSplits: 1).map(String.init)
            switch fields[0] {
            case "@Levels":
                levels = numbers(fields[1])

            case "@Reorder":
                order = numbers(fields[1]).compactMap(\.self)

            default:
                let parts = text.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                let scalars = parts[0].split(whereSeparator: \.isWhitespace).compactMap {
                    Self.representatives[String($0)]
                }
                let bitset = Int(parts[1], radix: 16) ?? 0
                let paragraphLevels: [(bit: Int, level: Int?)] = [(1, nil), (2, 0), (4, 1)]
                for paragraphLevel in paragraphLevels where bitset & paragraphLevel.bit != 0 {
                    cases.append(
                        ConformanceCase(
                            line: line,
                            scalars: scalars,
                            paragraphLevel: paragraphLevel.level,
                            resolvedParagraphLevel: nil,
                            levels: levels,
                            order: order
                        )
                    )
                }
            }
        }

        return cases
    }
}
