//
//  CoreTextShaperTests.swift
//  FramesCoreTextTests
//
//  Created by JSilver on 11/16/26.
//

import CoreText
import Foundation
import Frames
import FramesCoreText
import Testing

// CoreText's font matching can stop answering when many tasks ask it at once, so the tests run one at a time.
@Suite("CoreTextShaper Tests", .serialized)
struct CoreTextShaperTests {
    // MARK: - Property
    private let sut = CoreTextShaper()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "the machine's faces of a family are listed with their OS/2 weight, width and style and a font file that exists",
        arguments: [
            ("Helvetica", "Helvetica", 400),
            ("Helvetica", "Helvetica-Bold", 700),
            ("Apple SD Gothic Neo", "AppleSDGothicNeo-Regular", 400),
            ("Apple SD Gothic Neo", "AppleSDGothicNeo-Bold", 700)
        ]
    )
    func listsInstalledFaces(family: String, name: String, weight: Int) throws {
        // Given
        let files = FileManager.default

        // When
        let face = try #require(sut.installedFaces(family: family).first { $0.name == name })

        // Then
        #expect(face.weight == FontWeight(weight))
        #expect(face.width == 5)
        #expect(face.style == .upright)
        #expect(files.fileExists(atPath: face.file))
        #expect(face.ascent > 0 && face.ascent < 1.5)
        #expect(face.descent > 0 && face.descent < 1)
        #expect(face.underlineOffset > 0 && face.underlineOffset < 0.5)
        #expect(face.underlineThickness > 0 && face.underlineThickness < 0.2)
    }

    @Test("a family's condensed and italic faces are listed with their width and style, from the machine and its file")
    func listsWidthsAndStyles() throws {
        // Given
        let family = "Helvetica Neue"
        let file = "/System/Library/Fonts/HelveticaNeue.ttc"

        // When
        let installed = sut.installedFaces(family: family)
        let inFile = sut.faces(family: family, in: [file])

        // Then
        #expect(Set(installed.map(\.name)) == Set(inFile.map(\.name)))
        #expect(inFile.allSatisfy { $0.file == file })
        let condensed = try #require(inFile.first { $0.name == "HelveticaNeue-CondensedBold" })
        #expect(condensed.width < 5)
        #expect(condensed.weight == .bold)
        let italic = try #require(inFile.first { $0.name == "HelveticaNeue-Italic" })
        #expect(italic.style == .italic)
        #expect(italic.weight == .regular)
    }

    @Test("the face time labels are set in is found by its PostScript name in its file, and a name the file lacks is not")
    func findsFaceByName() throws {
        // Given
        let file = "/System/Library/Fonts/HelveticaNeue.ttc"

        // When
        let face = try #require(sut.face(named: "HelveticaNeue-Medium", in: file))
        let missing = sut.face(named: "HelveticaNeue-Missing", in: file)

        // Then
        #expect(face.name == "HelveticaNeue-Medium")
        #expect(face.file == file)
        #expect(face.weight == FontWeight(500))
        #expect(missing == nil)
        #expect(try shape("0.5s", [face]).allSatisfy { $0.face == face })
    }

    @Test("a family the machine does not have has no faces")
    func findsNoMissingFamily() {
        // Given
        let family = "No Such Family"

        // When
        let faces = sut.installedFaces(family: family)

        // Then
        #expect(faces.isEmpty)
    }

    @Test("a family whose weights lie in separate files lists the faces of every file")
    func listsAmongFiles() throws {
        // Given
        let regular = "/System/Library/Fonts/Supplemental/Arial.ttf"
        let bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

        // When
        let faces = sut.faces(family: "Arial", in: [regular, bold])

        // Then
        #expect(faces.first { $0.name == "Arial-BoldMT" }?.file == bold)
        #expect(faces.first { $0.name == "ArialMT" }?.file == regular)
    }

    @Test("the faces of a family are found in the font files given, and a family they do not hold has none")
    func listsFacesInFiles() throws {
        // Given
        let installed = try face("Apple SD Gothic Neo", "AppleSDGothicNeo-Regular")

        // When
        let faces = sut.faces(family: "Apple SD Gothic Neo", in: [installed.file])
        let other = sut.faces(family: "Helvetica", in: [installed.file])

        // Then
        #expect(faces.contains { $0.name == "AppleSDGothicNeo-Bold" && $0.file == installed.file })
        #expect(other.isEmpty)
    }

    @Test(
        "a run's advances sum to CoreText's typographic width of the line",
        arguments: [("Hello, World", "Helvetica", "Helvetica"), ("안녕하세요 세계", "Apple SD Gothic Neo", "AppleSDGothicNeo-Regular")]
    )
    func sumsAdvancesToLineWidth(text: String, family: String, name: String) throws {
        // Given
        let face = try face(family, name)

        // When
        let runs = try shape(text, [face])

        // Then
        #expect(runs.map(\.face) == [face])
        let width = runs.flatMap(\.glyphs).map(\.advance).reduce(0, +)
        #expect(abs(width - lineWidth(text, face: face.name, size: 48)) < 1e-9)
        #expect(runs.flatMap(\.glyphs).map(\.offset) == Array(0..<text.unicodeScalars.count))
    }

    @Test("kerning and ligatures are applied by default, and `kern` and `liga` at 0 turn them off")
    func kernsAndLigates() throws {
        // Given
        let face = try face("Helvetica", "Helvetica")
        let off = [FontFeature(tag: "kern", value: 0), FontFeature(tag: "liga", value: 0)]

        // When
        let pair = try shape("AV", [face]).flatMap(\.glyphs)
        let apart = try ["A", "V"].flatMap { try shape($0, [face]).flatMap(\.glyphs) }
        let ligature = try shape("fit", [face]).flatMap(\.glyphs)
        let unkerned = try shape("AV", [face], features: off).flatMap(\.glyphs)
        let unligated = try shape("fit", [face], features: off).flatMap(\.glyphs)

        // Then
        #expect(pair[0].advance < apart[0].advance)
        #expect(pair[1].advance == apart[1].advance)
        #expect(ligature.map(\.offset) == [0, 2])
        #expect(unkerned[0].advance == apart[0].advance)
        #expect(unligated.map(\.offset) == [0, 1, 2])
    }

    @Test(
        "a mark the face's GPOS table attaches has no advance, and its placement offset puts it where CoreText does",
        arguments: [("Times New Roman", "TimesNewRomanPSMT"), ("Arial", "ArialMT"), ("Courier New", "CourierNewPSMT")]
    )
    func placesMarkByOffset(family: String, name: String) throws {
        // Given
        let face = try face(family, name)
        let text = "xq\u{303}x"

        // When
        let glyphs = try shape(text, [face]).flatMap(\.glyphs)

        // Then
        #expect(glyphs.map(\.offset) == [0, 1, 2, 3])
        #expect(glyphs[2].advance == 0)
        #expect(glyphs[2].placementOffset.x < 0)
        #expect(glyphs[2].placementOffset.y != 0)
        #expect([0, 1, 3].allSatisfy { glyphs[$0].placementOffset == Point(x: 0, y: 0) })
        let pens = glyphs.indices.map { index in glyphs[..<index].map(\.advance).reduce(0, +) }
        let drawn = zip(pens, glyphs).map { pen, glyph in
            Point(x: pen + glyph.placementOffset.x, y: glyph.placementOffset.y)
        }
        let positions = positions(text, face: face.name, size: 48)
        #expect(zip(drawn, positions).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 })
    }

    @Test("characters the first face lacks are set in the later faces given, in order")
    func cascades() throws {
        // Given
        let latin = try face("Helvetica", "Helvetica")
        let hangul = try face("Apple SD Gothic Neo", "AppleSDGothicNeo-Regular")

        // When
        let runs = try shape("Send 보내기", [latin, hangul])

        // Then
        #expect(runs.map(\.face) == [latin, hangul])
        #expect(runs.last?.glyphs.map(\.offset) == [5, 6, 7])
    }

    @Test("a grapheme cluster is set whole in the first face given that has every scalar of it")
    func choosesFacePerCluster() throws {
        // Given
        let hangul = try face("Apple SD Gothic Neo", "AppleSDGothicNeo-Regular")
        let latin = try face("Helvetica", "Helvetica")

        // When
        let runs = try shape("Send e\u{303}", [hangul, latin])

        // Then
        #expect(runs.map(\.face) == [hangul, latin])
        #expect(runs.first?.glyphs.map(\.offset) == [0, 1, 2, 3, 4])
        #expect(runs.last?.glyphs.map(\.offset) == [5])
    }

    @Test(
        "a default ignorable scalar the face lacks takes no part in choosing the face and is set as nothing",
        arguments: [
            ("Helvetica", "Helvetica", "a\u{FE0F}b"),
            ("Hiragino Sans", "HiraginoSans-W3", "a\u{200D}b"),
            ("Hiragino Sans", "HiraginoSans-W3", "a\u{2060}b")
        ]
    )
    func leavesDefaultIgnorablesOut(family: String, name: String, text: String) throws {
        // Given
        let face = try face(family, name)

        // When
        let runs = try shape(text, [face])

        // Then
        #expect(runs.map(\.face) == [face])
        #expect(runs.flatMap(\.glyphs).map(\.offset) == [0, 2])
    }

    @Test(
        "a zero width non-joiner the face lacks keeps apart the glyphs the face would join, and is set as nothing",
        .enabled(if: !CoreTextShaper().installedFaces(family: "Hoefler Text").isEmpty)
    )
    func keepsNonJoinerApart() throws {
        // Given
        let face = try face("Hoefler Text", "HoeflerText-Regular")

        // When
        let joined = try shape("Auflage", [face])
        let apart = try shape("Auf\u{200C}lage", [face])

        // Then
        #expect(joined.flatMap(\.glyphs).map(\.offset) == [0, 1, 2, 4, 5, 6])
        #expect(apart.map(\.face) == [face])
        #expect(apart.flatMap(\.glyphs).map(\.offset) == [0, 1, 2, 4, 5, 6, 7])
    }

    @Test("a variation sequence the face maps is set in its variant glyph")
    func keepsVariationSequence() throws {
        // Given
        let face = try face("Hiragino Sans", "HiraginoSans-W3")

        // When
        let plain = try shape("葛", [face]).flatMap(\.glyphs)
        let variant = try shape("葛\u{E0100}", [face])

        // Then
        #expect(variant.map(\.face) == [face])
        #expect(variant.flatMap(\.glyphs).map(\.offset) == [0])
        #expect(variant.flatMap(\.glyphs).map(\.id) != plain.map(\.id))
    }

    @Test("a grapheme cluster no face given has whole is set whole in a face found on the machine")
    func fallsBackPerCluster() throws {
        // Given
        let face = try face("Apple SD Gothic Neo", "AppleSDGothicNeo-Regular")

        // When
        let runs = try shape("ae\u{303}", [face])

        // Then
        #expect(runs.count == 2)
        #expect(runs.first?.face == face)
        #expect(runs.first?.glyphs.map(\.offset) == [0])
        let fallback = try #require(runs.last)
        #expect(fallback.face != face)
        #expect(FileManager.default.fileExists(atPath: fallback.face.file))
        #expect(fallback.glyphs.map(\.offset).allSatisfy { $0 >= 1 })
    }

    @Test(
        "glyphs a script reorders keep glyph order, each with the scalar it was set from",
        arguments: [("र्क", [2, 0]), ("कि", [1, 0])]
    )
    func keepsReorderedOffsets(text: String, offsets: [Int]) throws {
        // Given
        let face = try face("Kohinoor Devanagari", "KohinoorDevanagari-Regular")

        // When
        let runs = try shape(text, [face])

        // Then
        #expect(runs.map(\.face) == [face])
        #expect(runs.flatMap(\.glyphs).map(\.offset) == offsets)
    }

    @Test("a right-to-left run's glyphs lie from right to left, each with the scalar it was set from, a mark placed as drawn")
    func setsRightToLeft() throws {
        // Given
        let face = try face("Arial Hebrew", "ArialHebrew")
        let text = "\u{5D1}\u{5B8}\u{5D0}"

        // When
        let glyphs = try shape(text, [face], direction: .rtl).flatMap(\.glyphs)

        // Then
        #expect(glyphs.map(\.offset) == [2, 1, 0])
        #expect(glyphs[1].advance == 0)
        #expect(glyphs[1].placementOffset.x != 0)
        let pens = glyphs.indices.map { index in glyphs[..<index].map(\.advance).reduce(0, +) }
        let drawn = zip(pens, glyphs).map { pen, glyph in
            Point(x: pen + glyph.placementOffset.x, y: glyph.placementOffset.y)
        }
        let positions = positions(text, face: face.name, size: 48)
        #expect(zip(drawn, positions).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 })
    }

    @Test("a bracket in a right-to-left run is set in its mirrored glyph, and the faces of the run lie from right to left")
    func mirrorsInRightToLeft() throws {
        // Given
        let latin = try face("Helvetica", "Helvetica")
        let hebrew = try face("Arial Hebrew", "ArialHebrew")
        let opening = try shape("(", [latin]).flatMap(\.glyphs).map(\.id)
        let closing = try shape(")", [latin]).flatMap(\.glyphs).map(\.id)

        // When
        let runs = try shape("(\u{5D0}\u{5D1})", [latin, hebrew], direction: .rtl)
        let kept = try shape("(ab)", [latin])

        // Then
        #expect(runs.map(\.face) == [latin, hebrew, latin])
        #expect(runs.map { $0.glyphs.map(\.offset) } == [[3], [2, 1], [0]])
        #expect(runs.first?.glyphs.map(\.id) == opening)
        #expect(runs.last?.glyphs.map(\.id) == closing)
        #expect(kept.flatMap(\.glyphs).first.map { [$0.id] } == opening)
    }

    @Test(
        "a run's glyphs lie in its direction whatever its text's first strong character says, a space at its end too",
        arguments: [
            (", ", "Helvetica", "Helvetica", TextDirection.rtl, [1, 0]),
            ("1 ", "Helvetica", "Helvetica", .rtl, [1, 0]),
            ("\u{5D0}\u{5D1} ", "Arial Hebrew", "ArialHebrew", .ltr, [0, 1, 2])
        ]
    )
    func keepsTrailingSpaceInRunDirection(
        text: String,
        family: String,
        name: String,
        direction: TextDirection,
        offsets: [Int]
    ) throws {
        // Given
        let face = try face(family, name)

        // When
        let runs = try shape(text, [face], direction: direction)

        // Then
        // Every scalar of the run lies at its one level, so the space at its end lies on the side the run ends on, left
        // in a right-to-left run and right in a left-to-right one. No glyph is placed against another, so each is drawn
        // at its pen.
        #expect(runs.map(\.face) == [face])
        #expect(runs.flatMap(\.glyphs).map(\.offset) == offsets)
        #expect(runs.flatMap(\.glyphs).allSatisfy { $0.placementOffset == Point(x: 0, y: 0) })
    }

    @Test("an Arabic word set right to left keeps its letters joined, and `lam` with `alef` is one glyph")
    func joinsArabic() throws {
        // Given
        let face = try face("Geeza Pro", "GeezaPro")
        let alone = try shape("\u{628}", [face], direction: .rtl).flatMap(\.glyphs).map(\.id)

        // When
        let word = try shape("\u{628}\u{628}", [face], direction: .rtl).flatMap(\.glyphs)
        let ligature = try shape("\u{644}\u{627}", [face], direction: .rtl).flatMap(\.glyphs)

        // Then
        #expect(word.map(\.offset) == [1, 0])
        #expect(word.allSatisfy { !alone.contains($0.id) })
        #expect(ligature.map(\.offset) == [0])
    }

    @Test("characters no face given has are set in a face found on the machine, which names its file")
    func fallsBack() throws {
        // Given
        let face = try face("Helvetica", "Helvetica")

        // When
        let runs = try shape("Send 보내기", [face])

        // Then
        #expect(runs.count == 2)
        #expect(runs.first?.face == face)
        #expect(runs.first?.glyphs.map(\.offset) == [0, 1, 2, 3, 4])
        let fallback = try #require(runs.last)
        #expect(fallback.face != face)
        #expect(FileManager.default.fileExists(atPath: fallback.face.file))
        #expect(fallback.glyphs.map(\.offset) == [5, 6, 7])
    }

    @Test("an upright run is set in the vertical forms of its face, each glyph its vertical advance long and set from its vertical origin")
    func setsVerticalForms() throws {
        // Given
        let face = try face("Hiragino Sans", "HiraginoSans-W3")
        let text = "、。「」ー漢"
        let horizontal = try shape(text, [face], size: 100).flatMap(\.glyphs).map(\.id)

        // When
        let glyphs = try shape(text, [face], upright: true, size: 100).flatMap(\.glyphs)

        // Then
        // Hiragino Sans W3 has an ascent of 88 at size 100, and its `VORG` table sets every vertical origin 88 above
        // the horizontal one.
        #expect(zip(glyphs.prefix(5).map(\.id), horizontal.prefix(5)).allSatisfy { $0 != $1 })
        #expect(glyphs.last?.id == horizontal.last)
        #expect(glyphs.map(\.offset) == [0, 1, 2, 3, 4, 5])
        #expect(glyphs.allSatisfy { isNear($0.advance, 100) })
        #expect(glyphs.allSatisfy { isNear($0.placementOffset, Point(x: 88, y: 50)) })
    }

    @Test("an upright glyph's advance is its vertical one, and its vertical origin lies half its horizontal advance across")
    func setsVerticalAdvance() throws {
        // Given
        let face = try face("Hiragino Sans", "HiraginoSans-W3")
        let features = [FontFeature(tag: "vert", value: 0)]
        let horizontal = try #require(try shape("±", [face], size: 100, features: features).first?.glyphs.first)

        // When
        let glyph = try #require(try shape("±", [face], upright: true, size: 100, features: features).first?.glyphs.first)

        // Then
        #expect(glyph.id == horizontal.id)
        #expect(!isNear(horizontal.advance, 100))
        #expect(isNear(glyph.advance, 100))
        #expect(isNear(glyph.placementOffset, Point(x: 88, y: horizontal.advance / 2)))
    }

    @Test("an upright glyph of a face with `vmtx` and no `VORG` is set from the top of its outline less its top side bearing")
    func setsVerticalOriginWithoutOriginTable() throws {
        // Given
        let face = try face("Songti SC", "STSongti-SC-Regular")

        // When
        let glyph = try #require(try shape("漢", [face], upright: true, size: 100).first?.glyphs.first)

        // Then
        // 漢 has a top side bearing of 3.2 and an outline 76.8 high at size 100.
        #expect(!isNear(face.ascent * 100, 80))
        #expect(isNear(glyph.advance, 100))
        #expect(isNear(glyph.placementOffset, Point(x: 80, y: 50)))
    }

    @Test("an upright glyph of a face without `vmtx` is its face's ascent and descent long and set from its ascent")
    func makesVerticalMetrics() throws {
        // Given
        let face = try face("Arial", "ArialMT")
        let text = "§±"
        let horizontal = try shape(text, [face], size: 100).flatMap(\.glyphs)

        // When
        let glyphs = try shape(text, [face], upright: true, size: 100).flatMap(\.glyphs)

        // Then
        #expect(glyphs.map(\.id) == horizontal.map(\.id))
        #expect(glyphs.allSatisfy { isNear($0.advance, (face.ascent + face.descent) * 100) })
        #expect(zip(glyphs, horizontal).allSatisfy { upright, glyph in
            isNear(upright.placementOffset, Point(x: face.ascent * 100, y: glyph.advance / 2))
        })
    }

    @Test("a right-to-left upright run lies from its end, its brackets mirrored and its trailing space first")
    func setsUprightRightToLeft() throws {
        // Given
        let face = try face("Hiragino Sans", "HiraginoSans-W3")
        let mirrored = try shape("」漢「", [face], upright: true, size: 100).flatMap(\.glyphs).map(\.id)

        // When
        let glyphs = try shape("「漢」\u{3000}", [face], direction: .rtl, upright: true, size: 100).flatMap(\.glyphs)

        // Then
        #expect(glyphs.map(\.offset) == [3, 2, 1, 0])
        #expect(Array(glyphs.dropFirst().map(\.id)) == mirrored.reversed())
        #expect(glyphs.allSatisfy { isNear($0.placementOffset, Point(x: 88, y: 50)) })
    }

    @Test("an upright character no face given has is set in the face found on the machine, read as horizontal text reads it")
    func fallsBackUpright() throws {
        // Given
        let face = try face("Helvetica", "Helvetica")
        let horizontal = try shape("漢", [face], size: 100)

        // When
        let upright = try shape("漢", [face], upright: true, size: 100)

        // Then
        let fallback = try #require(upright.first?.face)
        #expect(upright.map(\.face) == horizontal.map(\.face))
        #expect(fallback != face)
        #expect(upright.map(\.glyphs.count) == [1])
    }

    @Test("a face its file does not hold stops")
    func stopsOnFaceNotInFile() throws {
        // Given
        let installed = try face("Helvetica", "Helvetica")
        let face = FontFace(
            file: installed.file,
            name: "NoSuchFace",
            weight: .regular,
            width: 5,
            style: .upright,
            ascent: 0.8,
            descent: 0.2,
            underlineOffset: 0.1,
            underlineThickness: 0.05
        )

        // When
        let error = #expect(throws: ShapingError.self) { try shape("Send", [face]) }

        // Then
        #expect(error?.description == "font file \(installed.file) holds no face NoSuchFace")
    }

    // MARK: - Private
    private func face(
        _ family: String,
        _ name: String
    ) throws -> FontFace {
        try #require(sut.installedFaces(family: family).first { $0.name == name })
    }

    private func shape(
        _ text: String,
        _ faces: [FontFace],
        direction: TextDirection = .ltr,
        upright: Bool = false,
        size: Double = 48,
        features: [FontFeature] = []
    ) throws -> [ShapedRun] {
        try sut.shape(
            text,
            direction: direction,
            upright: upright,
            faces: faces,
            size: size,
            features: features,
            weight: .regular,
            italic: false
        )
    }

    private func isNear(
        _ value: Double,
        _ expected: Double
    ) -> Bool {
        abs(value - expected) < 1e-6
    }

    private func isNear(
        _ point: Point,
        _ expected: Point
    ) -> Bool {
        isNear(point.x, expected.x) && isNear(point.y, expected.y)
    }

    private func lineWidth(
        _ text: String,
        face name: String,
        size: Double
    ) -> Double {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))

        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    // Where CoreText draws each glyph of `text` in one line, y down.
    private func positions(
        _ text: String,
        face name: String,
        size: Double
    ) -> [Point] {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))

        return (CTLineGetGlyphRuns(line) as? [CTRun] ?? []).flatMap { run in
            var positions = [CGPoint](repeating: .zero, count: CTRunGetGlyphCount(run))
            CTRunGetPositions(run, CFRange(location: 0, length: positions.count), &positions)

            return positions.map { Point(x: Double($0.x), y: -Double($0.y)) }
        }
    }
}
