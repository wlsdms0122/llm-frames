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

@Suite("CoreTextShaper Tests")
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
        features: [FontFeature] = []
    ) throws -> [ShapedRun] {
        try sut.shape(text, faces: faces, size: 48, features: features, weight: .regular, italic: false)
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
}
