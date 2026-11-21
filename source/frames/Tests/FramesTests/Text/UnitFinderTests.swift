//
//  UnitFinderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Every character is one glyph 20 wide in the run a test names, glyph run 0 unless it says otherwise, and lines lie 50
// apart, the first from y 0 to 40. The spaces that end a line hang past it.
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
            ("$5 now", ["$5", "now"]),
            ("안녕하세요 여러분", ["안녕하세요", "여러분"]),
            ("iPhone에서 봐요", ["iPhone에서", "봐요"]),
            ("漢字です", ["漢", "字", "で", "す"]),
            ("カタカナ語", ["カタカナ", "語"])
        ]
    )
    func findsWords(text: String, words: [String]) {
        // Given
        let title = title([[(text, 0)]])

        // When
        let units = self.units(by: .word, of: title, runs: [run(text)])

        // Then
        #expect(units.map { held(by: $0, in: title) } == words)
    }

    @Test("a character in no word and no punctuation is held by the unit before it on its line, or by the next")
    func holdsCharactersInNoWord() {
        // Given
        let between = title([[("ab \u{2060} cd", 0)]])
        let before = title([[("\u{2060} ab", 0)]])
        let raised = title([[("m² x", 0)]])

        // When
        let units = [between, before, raised].map { title in
            units(by: .word, of: title, runs: [run(title.text)])
        }

        // Then
        #expect(units[0].map { held(by: $0, in: between) } == ["ab\u{2060}", "cd"])
        #expect(units[0].map(\.characters) == [characters(0, 0, 5), characters(0, 5, 2)])
        #expect(units[1].map { held(by: $0, in: before) } == ["\u{2060}ab"])
        #expect(units[2].map { held(by: $0, in: raised) } == ["m²", "x"])
    }

    @Test("a character that is not a space, on a line that would hold no unit, is a unit of its own")
    func makesUnitOfCharacterAlone() {
        // Given
        let title = title([[("ab", 0)], [("\u{2060}", 1)]])
        let runs = [run("ab"), run("\u{2060}", line: 1)]

        // When
        let units = self.units(by: .word, of: title, runs: runs)

        // Then
        #expect(units.map(\.characters) == [characters(0, 0, 2), characters(1, 0, 1)])
    }

    @Test(
        "a word a line breaks inside is cut by the line, its punctuation kept with the word it belongs to",
        arguments: [
            (["Hello", "—world"], ["Hello", "—", "world"]),
            (["漢字", "「かな」"], ["漢", "字", "「", "か", "な」"])
        ]
    )
    func cutsWordsByLine(lines: [String], units: [String]) {
        // Given
        let title = title(lines.enumerated().map { [($1, $0)] }, separator: "")
        let runs = lines.enumerated().map { run($1, line: $0) }

        // When
        let found = self.units(by: .word, of: title, runs: runs)

        // Then
        #expect(found.map { held(by: $0, in: title) } == units)
    }

    @Test("a unit draws the spaces that go with it, and a line of spaces is no line unit")
    func drawsSpacesWithUnits() {
        // Given
        let title = title([[(" a b", 0)], [("  ", 1)]])
        let runs = [run(" a b"), run("  ", line: 1)]

        // When
        let characters = self.units(by: .character, of: title, runs: runs)
        let lines = self.units(by: .line, of: title, runs: runs)

        // Then
        #expect(characters.map(\.characters) == [self.characters(0, 0, 3), self.characters(0, 3, 1)])
        #expect(characters.map(\.glyphs) == [[range(0, 0, 3)], [range(0, 3, 1), range(1, 0, 2)]])
        #expect(characters.map(\.glyphBox) == [
            Rectangle(x: 20, y: 0, width: 20, height: 40),
            Rectangle(x: 60, y: 0, width: 20, height: 40)
        ])
        #expect(lines.map(\.characters) == [self.characters(0, 0, 4)])
        #expect(lines.map(\.box) == [Rectangle(x: 20, y: 0, width: 60, height: 40)])
    }

    @Test(
        "a line's hanging spaces are drawn by its last unit, and a line of spaces by the unit before it, or the first"
    )
    func drawsHangingSpaces() {
        // Given
        let between = title([[("ab ", 0)], [("  ", 1)], [("cd", 2)]])
        let first = title([[(" ", 0)], [("ab ", 1)]])

        // When
        let afterWords = sut.units(
            by: .word,
            text: between.text,
            words: between.words,
            lines: between.lines,
            spans: between.spans,
            runs: [run("ab "), run("  ", line: 1), run("cd", line: 2)]
        )
        let beforeWords = sut.units(
            by: .word,
            text: first.text,
            words: first.words,
            lines: first.lines,
            spans: first.spans,
            runs: [run(" "), run("ab ", line: 1)]
        )

        // Then
        #expect(afterWords.map(\.hangingLines) == [[0, 1], []])
        #expect(afterWords.map(\.glyphs) == [[range(0, 0, 3), range(1, 0, 2)], [range(2, 0, 2)]])
        #expect(beforeWords.map(\.hangingLines) == [[0, 1]])
        #expect(beforeWords.map(\.glyphs) == [[range(1, 0, 2), range(0, 0, 1), range(1, 2, 1)]])
    }

    @Test("a title with no character has no unit")
    func findsNoUnitWithoutCharacters() {
        // Given
        let title = title([[("  ", 0)], [("", 0)]])

        // When
        let units = self.units(by: .word, of: title, runs: [run("  ")])

        // Then
        #expect(units.isEmpty)
    }

    @Test("units that the characters of one group of glyphs go with are one unit, a group led by a space included")
    func mergesUnitsOfOneGroup() {
        // Given
        // "f" and "i" are one glyph 30 wide, and so are " " and "b".
        let ligature = line(
            [
                PlacedCluster(glyphs: range(0, 0, 1), range: 0..<1, advance: 30),
                PlacedCluster(glyphs: range(0, 1, 0), range: 1..<2, advance: 0),
                PlacedCluster(glyphs: range(0, 1, 1), range: 2..<3, advance: 20)
            ],
            width: 50
        )
        let spaced = line(
            [
                PlacedCluster(glyphs: range(0, 0, 1), range: 0..<1, advance: 20),
                PlacedCluster(glyphs: range(0, 1, 1), range: 1..<2, advance: 30),
                PlacedCluster(glyphs: range(0, 2, 0), range: 2..<3, advance: 0),
                PlacedCluster(glyphs: range(0, 2, 1), range: 3..<4, advance: 20)
            ],
            width: 70
        )

        // When
        let joined = sut.units(
            by: .character,
            text: "fix",
            words: words(of: "fix"),
            lines: [ligature],
            spans: [[0...30, 0...30, 30...50]],
            runs: [run("fx")]
        )
        let led = sut.units(
            by: .character,
            text: "a bc",
            words: words(of: "a bc"),
            lines: [spaced],
            spans: [[0...20, 20...50, 20...50, 50...70]],
            runs: [run("a c")]
        )

        // Then
        #expect(joined.map(\.characters) == [characters(0, 0, 2), characters(0, 2, 1)])
        #expect(joined.map(\.box.width) == [30, 20])
        #expect(led.map(\.characters) == [characters(0, 0, 3), characters(0, 3, 1)])
        #expect(led.map(\.glyphBox.width) == [50, 20])
    }

    @Test("a piece is cut at the first character of every unit after the first, its first and last parts at its ends")
    func cutsPiecesIntoParts() {
        // Given
        let title = title([[("ab cd ef", 0)]])
        let highlighted = run("ab cd ef", highlight: Rectangle(x: 0, y: 0, width: 160, height: 40))

        // When
        let units = self.units(by: .word, of: title, runs: [highlighted])

        // Then
        #expect(units.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...60)],
            [UnitPart(run: 0, piece: 0, span: 60...120)],
            [UnitPart(run: 0, piece: 0, span: 120...160)]
        ])
    }

    @Test("a piece of spaces alone is carried by the unit its spaces go with, on its line")
    func givesSpacePiecesToTheirUnit() {
        // Given
        let title = title([[(" ", 0), ("ab", 1), (" ", 2), ("cd", 3)], [(" ", 4), ("ef", 5)]])
        let space = { (run: Int, line: Int, x: Double) in
            let highlight = Rectangle(x: x, y: Double(line) * 50, width: 20, height: 40)
            return self.run(" ", source: run, line: line, highlight: highlight)
        }
        let runs = [
            space(0, 0, 0),
            run("ab", source: 1),
            space(2, 0, 60),
            run("cd", source: 3),
            space(4, 1, 0),
            run("ef", source: 5, line: 1)
        ]

        // When
        let units = self.units(by: .word, of: title, runs: runs)

        // Then
        #expect(units.map(\.parts) == [
            [UnitPart(run: 0, piece: 0, span: 0...20), UnitPart(run: 2, piece: 0, span: 60...80)],
            [],
            [UnitPart(run: 4, piece: 0, span: 0...20)]
        ])
    }

    @Test("a piece held by a run whose glyphs lie in no character goes with the unit of its text run on its line")
    func keepsPiecesOfRunsInNoCharacter() {
        // Given
        // Run 0 holds the piece and the glyphs of no character.
        let line = line([PlacedCluster(glyphs: range(1, 0, 1), range: 0..<1, advance: 40)], width: 40)
        let runs = [run("a", highlight: Rectangle(x: 0, y: 0, width: 40, height: 40)), run("a")]

        // When
        let units = sut.units(by: .word, text: "a", words: words(of: "a"), lines: [line], spans: [[0...40]], runs: runs)

        // Then
        #expect(units.map(\.parts) == [[UnitPart(run: 0, piece: 0, span: 0...40)]])
    }

    // MARK: - Private
    // A title of lines, each a list of pieces of text in the glyph run they name, one glyph a character, and its words.
    // The lines are joined by `separator`, which is empty for lines a width wraps.
    private func title(
        _ lines: [[(text: String, run: Int)]],
        separator: String = "\n"
    ) -> (
        text: String,
        words: [Range<Int>],
        lines: [PlacedLine],
        spans: [[ClosedRange<Double>]]
    ) {
        var offset = 0
        var placed: [PlacedLine] = []
        var spans: [[ClosedRange<Double>]] = []
        for (index, pieces) in lines.enumerated() {
            var clusters: [(cluster: PlacedCluster, isSpace: Bool, span: ClosedRange<Double>)] = []
            var glyphs: [Int: Int] = [:]
            for (text, run) in pieces {
                for character in text {
                    let count = character.unicodeScalars.count
                    let first = glyphs[run, default: 0]
                    let x = Double(clusters.count) * 20
                    let cluster = PlacedCluster(
                        glyphs: range(run, first, 1),
                        range: offset..<(offset + count),
                        advance: 20
                    )
                    let isSpace = character.unicodeScalars.first?.properties.isWhitespace ?? false
                    clusters.append((cluster, isSpace, x...(x + 20)))
                    glyphs[run] = first + 1
                    offset += count
                }
            }
            offset += separator.unicodeScalars.count

            let visible = clusters.dropLast(clusters.reversed().prefix(while: \.isSpace).count)
            let top = Double(index) * 50
            placed.append(PlacedLine(
                width: Double(visible.count) * 20,
                baseline: top + 32,
                ascent: 32,
                descent: 8,
                range: (visible.first?.cluster.range.lowerBound ?? 0)..<(visible.last?.cluster.range.upperBound ?? 0),
                clusters: visible.map(\.cluster),
                hanging: clusters.dropFirst(visible.count).map(\.cluster)
            ))
            spans.append(visible.map(\.span))
        }

        let text = lines.map { $0.map(\.text).joined() }.joined(separator: separator)

        return (text, words(of: text), placed, spans)
    }

    private func units(
        by unit: TextUnit,
        of title: (text: String, words: [Range<Int>], lines: [PlacedLine], spans: [[ClosedRange<Double>]]),
        runs: [GlyphRun]
    ) -> [PlacedUnit] {
        sut.units(by: unit, text: title.text, words: title.words, lines: title.lines, spans: title.spans, runs: runs)
    }

    // The words of `text`, each its range of Unicode scalars.
    private func words(of text: String) -> [Range<Int>] {
        text.scalarRanges(of: WordSegmenter().words(of: Array(text)))
    }

    private func line(
        _ clusters: [PlacedCluster],
        width: Double
    ) -> PlacedLine {
        PlacedLine(
            width: width,
            baseline: 32,
            ascent: 32,
            descent: 8,
            range: (clusters.first?.range.lowerBound ?? 0)..<(clusters.last?.range.upperBound ?? 0),
            clusters: clusters,
            hanging: []
        )
    }

    // A glyph run of one glyph for each character of `text`.
    private func run(
        _ text: String,
        source: Int = 0,
        line: Int = 0,
        highlight: Rectangle? = nil
    ) -> GlyphRun {
        GlyphRun(
            source: source,
            line: line,
            face: ShaperTable.face("Apple SD Gothic Neo", .bold),
            size: 40,
            glyphs: (0..<text.count).map { PositionedGlyph(id: 0, x: Double($0) * 20, y: 32) },
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

    private func characters(
        _ line: Int,
        _ first: Int,
        _ count: Int
    ) -> CharacterRange {
        CharacterRange(line: line, first: first, count: count)
    }

    // The text of the characters a unit holds: those of its stretch but its spaces.
    private func held(
        by unit: PlacedUnit,
        in title: (text: String, words: [Range<Int>], lines: [PlacedLine], spans: [[ClosedRange<Double>]])
    ) -> String {
        let scalars = Array(title.text.unicodeScalars)
        let clusters = title.lines[unit.characters.line].clusters
        let stretch = clusters[unit.characters.first..<(unit.characters.first + unit.characters.count)]
        var view = String.UnicodeScalarView()
        for cluster in stretch where !scalars[cluster.range.lowerBound].properties.isWhitespace {
            view.append(contentsOf: scalars[cluster.range])
        }

        return String(view)
    }
}
