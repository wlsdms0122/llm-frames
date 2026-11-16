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
        "the machine's face of a family is found in its weight, with a font file that exists",
        arguments: [
            ("Helvetica", FontWeight.regular, "Helvetica"),
            ("Helvetica", .bold, "Helvetica-Bold"),
            ("Apple SD Gothic Neo", .regular, "AppleSDGothicNeo-Regular"),
            ("Apple SD Gothic Neo", .bold, "AppleSDGothicNeo-Bold")
        ]
    )
    func findsInstalledFace(family: String, weight: FontWeight, name: String) throws {
        // Given
        let files = FileManager.default

        // When
        let face = try #require(sut.installedFace(family: family, weight: weight))

        // Then
        #expect(face.name == name)
        #expect(files.fileExists(atPath: face.file))
        #expect(face.ascent > 0 && face.ascent < 1.5)
        #expect(face.descent > 0 && face.descent < 1)
    }

    @Test(
        "a family with condensed faces gives its normal width face, from the machine and from its file",
        arguments: [(FontWeight.regular, "HelveticaNeue"), (.bold, "HelveticaNeue-Bold")]
    )
    func prefersNormalWidth(weight: FontWeight, name: String) throws {
        // Given
        let family = "Helvetica Neue"
        let file = "/System/Library/Fonts/HelveticaNeue.ttc"

        // When
        let installed = try #require(sut.installedFace(family: family, weight: weight))
        let inFile = try #require(sut.face(family: family, weight: weight, in: [file]))

        // Then
        #expect(installed.name == name)
        #expect(inFile.name == name)
        #expect(inFile.file == file)
    }

    // Skia's one normal width face weighs 0.2, and condensed faces of it weigh 0 and 0.35.
    @Test(
        "where only condensed faces have the weight asked for, the normal width face of the nearest weight wins",
        arguments: [FontWeight.regular, .bold]
    )
    func narrowsByWidthFirst(weight: FontWeight) throws {
        // Given
        let family = "Skia"

        // When
        let face = try #require(sut.installedFace(family: family, weight: weight))

        // Then
        #expect(face.name == "Skia-Regular")
    }

    @Test("a family the machine does not have has no face")
    func findsNoMissingFamily() {
        // Given
        let family = "No Such Family"

        // When
        let face = sut.installedFace(family: family, weight: .regular)

        // Then
        #expect(face == nil)
    }

    @Test("a family whose weights lie in separate files gives the face of the weight asked for, whatever the file order")
    func choosesAmongFiles() throws {
        // Given
        let regular = "/System/Library/Fonts/Supplemental/Arial.ttf"
        let bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

        // When
        let boldFace = sut.face(family: "Arial", weight: .bold, in: [regular, bold])
        let regularFace = sut.face(family: "Arial", weight: .regular, in: [bold, regular])

        // Then
        #expect(boldFace?.name == "Arial-BoldMT")
        #expect(boldFace?.file == bold)
        #expect(regularFace?.name == "ArialMT")
        #expect(regularFace?.file == regular)
    }

    @Test("a face of a family is found in the font files given, and a family they do not hold is not")
    func findsFaceInFiles() throws {
        // Given
        let installed = try #require(sut.installedFace(family: "Apple SD Gothic Neo", weight: .regular))

        // When
        let bold = sut.face(family: "Apple SD Gothic Neo", weight: .bold, in: [installed.file])
        let other = sut.face(family: "Helvetica", weight: .regular, in: [installed.file])

        // Then
        #expect(bold?.name == "AppleSDGothicNeo-Bold")
        #expect(bold?.file == installed.file)
        #expect(other == nil)
    }

    @Test(
        "a run's advances sum to CoreText's typographic width of the line",
        arguments: [("Hello, World", "Helvetica"), ("안녕하세요 세계", "Apple SD Gothic Neo")]
    )
    func sumsAdvancesToLineWidth(text: String, family: String) throws {
        // Given
        let face = try #require(sut.installedFace(family: family, weight: .regular))

        // When
        let runs = try sut.shape(text, face: face, size: 48)

        // Then
        #expect(runs.map(\.face) == [face])
        let width = runs.flatMap(\.glyphs).map(\.advance).reduce(0, +)
        #expect(abs(width - lineWidth(text, face: face.name, size: 48)) < 1e-9)
        #expect(runs.flatMap(\.glyphs).map(\.offset) == Array(0..<text.unicodeScalars.count))
    }

    @Test("kerning and ligatures are applied as CoreText applies them by default")
    func kernsAndLigates() throws {
        // Given
        let face = try #require(sut.installedFace(family: "Helvetica", weight: .regular))

        // When
        let pair = try sut.shape("AV", face: face, size: 48).flatMap(\.glyphs)
        let apart = try ["A", "V"].flatMap { try sut.shape($0, face: face, size: 48).flatMap(\.glyphs) }
        let ligature = try sut.shape("fit", face: face, size: 48).flatMap(\.glyphs)

        // Then
        #expect(pair[0].advance < apart[0].advance)
        #expect(pair[1].advance == apart[1].advance)
        #expect(ligature.map(\.offset) == [0, 2])
    }

    @Test("characters the face lacks are set in a face found on the machine, which names its file")
    func fallsBack() throws {
        // Given
        let face = try #require(sut.installedFace(family: "Helvetica", weight: .regular))

        // When
        let runs = try sut.shape("Send 보내기", face: face, size: 48)

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
        let installed = try #require(sut.installedFace(family: "Helvetica", weight: .regular))
        let face = FontFace(file: installed.file, name: "NoSuchFace", ascent: 0.8, descent: 0.2)

        // When
        let error = #expect(throws: ShapingError.self) { try sut.shape("Send", face: face, size: 48) }

        // Then
        #expect(error?.description == "font file \(installed.file) holds no face NoSuchFace")
    }

    // MARK: - Private
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
