//
//  UnitFinderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Every cluster is one glyph 20 wide in run 0, unless a test sets it otherwise, on a line from y 0 to 40.
@Suite("Unit Finder Tests")
struct UnitFinderTests {
    // MARK: - Property
    private let sut = UnitFinder()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a word takes the punctuation it touches, the word before it when it touches two",
        arguments: [
            ("Hello, world", ["Hello,", "world"]),
            ("\"Quote\" marks", ["\"Quote\"", "marks"]),
            ("well - said", ["well", "-", "said"]),
            ("foo-bar", ["foo-", "bar"]),
            ("(see) it's 3.14!", ["(see)", "it's", "3.14!"]),
            ("안녕하세요 여러분", ["안녕하세요", "여러분"]),
            ("iPhone에서 봐요", ["iPhone에서", "봐요"]),
            ("漢字です", ["漢", "字", "で", "す"]),
            ("カタカナ語", ["カタカナ", "語"])
        ]
    )
    func findsWords(text: String, words: [String]) {
        // Given
        let clusters = clusters(of: text)

        // When
        let units = sut.units(by: .word, lines: [clusters], extents: [0...40], runs: [run(count: clusters.count)])

        // Then
        #expect(units.map { self.text(of: $0, in: text) } == words)
    }

    @Test("every cluster but a space is a character unit, and a line of spaces is no line unit")
    func findsCharactersAndLines() {
        // Given
        let lines = [clusters(of: "a b"), clusters(of: "  ", run: 1)]
        let runs = [run(count: 3), run(count: 2)]

        // When
        let characters = sut.units(by: .character, lines: lines, extents: [0...40, 50...90], runs: runs)
        let lineUnits = sut.units(by: .line, lines: lines, extents: [0...40, 50...90], runs: runs)

        // Then
        #expect(characters.map(\.glyphs) == [[range(0, 0, 1)], [range(0, 2, 1)]])
        #expect(lineUnits.map(\.glyphs) == [[range(0, 0, 1), range(0, 2, 1)]])
        #expect(lineUnits.map(\.box) == [Rectangle(x: 0, y: 0, width: 60, height: 40)])
    }

    @Test("characters set in one glyph are one unit")
    func mergesUnitsSharingAGlyph() {
        // Given
        let clusters: [UnitFinder.Cluster] = [
            (PlacedCluster(glyphs: range(0, 0, 1), range: 0..<1, advance: 30), "f", 0...30),
            (PlacedCluster(glyphs: range(0, 1, 0), range: 1..<2, advance: 0), "i", 0...30),
            (PlacedCluster(glyphs: range(0, 1, 1), range: 2..<3, advance: 20), "x", 30...50)
        ]

        // When
        let units = sut.units(by: .character, lines: [clusters], extents: [0...40], runs: [run(count: 2)])

        // Then
        #expect(units.map(\.glyphs) == [[range(0, 0, 1)], [range(0, 1, 1)]])
        #expect(units.map(\.box.width) == [30, 20])
    }

    @Test("a piece is cut at the first glyph of every unit after the first, its first and last parts at its ends")
    func cutsPiecesIntoParts() {
        // Given
        let clusters = clusters(of: "ab cd ef")
        let highlighted = run(count: 8, highlight: Rectangle(x: 0, y: 0, width: 160, height: 40))

        // When
        let units = sut.units(by: .word, lines: [clusters], extents: [0...40], runs: [highlighted])

        // Then
        #expect(units.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...60)],
            [UnitPart(run: 0, piece: 0, span: 60...120)],
            [UnitPart(run: 0, piece: 0, span: 120...160)]
        ])
    }

    @Test("a piece of spaces alone goes with the unit before it, or the first when none is before it")
    func givesSpacePiecesToTheUnitBefore() {
        // Given
        let clusters = clusters(of: " ", run: 0) + clusters(of: "ab", run: 1, from: 1)
            + clusters(of: " ", run: 2, from: 3) + clusters(of: "cd", run: 3, from: 4)
        let space = { (run: Int, x: Double) in
            GlyphRun(
                source: run,
                line: 0,
                face: ShaperTable.face("Apple SD Gothic Neo", .bold),
                size: 40,
                glyphs: [PositionedGlyph(id: 32, x: x, y: 32)],
                highlights: [Rectangle(x: x, y: 0, width: 20, height: 40)]
            )
        }
        let runs = [space(0, 0), run(count: 2, source: 1), space(2, 60), run(count: 2, source: 3)]

        // When
        let units = sut.units(by: .word, lines: [clusters], extents: [0...40], runs: runs)

        // Then
        #expect(units.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...20), UnitPart(run: 2, piece: 0, span: 60...80)],
            []
        ])
    }

    @Test("a piece of spaces alone at the start of a line goes with that line's first unit, not the line before")
    func keepsSpacePiecesOnTheirLine() {
        // Given
        let lines = [clusters(of: "ab"), clusters(of: " ", run: 1) + clusters(of: "cd", run: 2, from: 1)]
        let runs = [
            run(count: 2),
            run(count: 1, source: 1, line: 1, highlight: Rectangle(x: 0, y: 50, width: 20, height: 40)),
            run(count: 2, source: 2, line: 1)
        ]

        // When
        let units = sut.units(by: .word, lines: lines, extents: [0...40, 50...90], runs: runs)

        // Then
        #expect(units.map(\.parts) == [[], [UnitPart(run: 1, piece: 0, span: 0...20)]])
    }

    @Test(
        "a piece of spaces alone on a line with no unit goes with the unit before it in reading order, or the first"
    )
    func givesPiecesOnLinesWithoutUnits() {
        // Given
        let spaces = { (line: Int, y: Double) in
            run(count: 1, source: 1, line: line, highlight: Rectangle(x: 0, y: y, width: 20, height: 40))
        }
        let between = [clusters(of: "ab"), clusters(of: " ", run: 1), clusters(of: "cd", run: 2)]
        let first = [clusters(of: " "), clusters(of: "ab", run: 1)]

        // When
        let afterWords = sut.units(
            by: .word,
            lines: between,
            extents: [0...40, 50...90, 100...140],
            runs: [run(count: 2), spaces(1, 50), run(count: 2, source: 2, line: 2)]
        )
        let beforeWords = sut.units(
            by: .word,
            lines: first,
            extents: [0...40, 50...90],
            runs: [spaces(0, 0), run(count: 2, source: 2, line: 1)]
        )

        // Then
        #expect(afterWords.map(\.parts) == [[UnitPart(run: 1, piece: 0, span: 0...20)], []])
        #expect(beforeWords.map(\.parts) == [[UnitPart(run: 0, piece: 0, span: 0...20)]])
    }

    @Test("a piece held by a run whose glyphs lie in no cluster goes with the unit of its text run on its line")
    func keepsPiecesOfRunsInNoCluster() {
        // Given
        // Run 0 holds the piece and the glyphs of no character.
        let lines: [[UnitFinder.Cluster]] = [[(PlacedCluster(glyphs: range(1, 0, 1), range: 0..<1, advance: 40), "a", 0...40)]]
        let runs = [
            run(count: 1, highlight: Rectangle(x: 0, y: 0, width: 40, height: 40)),
            run(count: 1)
        ]

        // When
        let units = sut.units(by: .word, lines: lines, extents: [0...40], runs: runs)

        // Then
        #expect(units.map(\.parts) == [[UnitPart(run: 0, piece: 0, span: 0...40)]])
    }

    // MARK: - Private
    private func clusters(
        of text: String,
        run: Int = 0,
        from start: Int = 0
    ) -> [UnitFinder.Cluster] {
        text.enumerated().map { index, character in
            let x = Double(start + index) * 20
            let cluster = PlacedCluster(glyphs: range(run, index, 1), range: (start + index)..<(start + index + 1), advance: 20)

            return (cluster, character, x...(x + 20))
        }
    }

    private func run(
        count: Int,
        source: Int = 0,
        line: Int = 0,
        highlight: Rectangle? = nil
    ) -> GlyphRun {
        GlyphRun(
            source: source,
            line: line,
            face: ShaperTable.face("Apple SD Gothic Neo", .bold),
            size: 40,
            glyphs: (0..<count).map { PositionedGlyph(id: 0, x: Double($0) * 20, y: 32) },
            highlights: highlight.map { [$0] } ?? []
        )
    }

    private func range(
        _ run: Int,
        _ first: Int,
        _ count: Int
    ) -> GlyphRange {
        GlyphRange(run: run, first: first, count: count)
    }

    // The characters of a unit's glyphs, every cluster being one glyph of run 0.
    private func text(
        of unit: PlacedUnit,
        in text: String
    ) -> String {
        let characters = Array(text)
        return String(unit.glyphs.flatMap { characters[$0.first..<($0.first + $0.count)] })
    }
}
