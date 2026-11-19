//
//  FontFinderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("FontFinder Tests")
struct FontFinderTests {
    // MARK: - Property
    private let directory: PackDirectory
    private let fontFile: String

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write("", in: "shorts", at: "fonts/.DS_Store")
        try directory.write("", in: "shorts", at: "fonts/Pretendard-Bold.otf")
        fontFile = try directory.write("", in: "shorts", at: "fonts/Inter-Bold.otf").path
    }

    // MARK: - Test
    @Test("a pack's font files are listed in name order, without hidden files")
    func listsPackFonts() throws {
        // Given
        let sut = directory.library()

        // When
        let files = try sut.fontFiles(inPack: "shorts")
        let none = try sut.fontFiles(inPack: "missing")

        // Then
        #expect(files.map { $0.split(separator: "/").last.map(String.init) } == ["Inter-Bold.otf", "Pretendard-Bold.otf"])
        #expect(none.isEmpty)
    }

    @Test("a pack's fonts folder that is there but cannot be read stops")
    func refusesUnreadableFonts() throws {
        // Given
        let sut = directory.library()
        let fonts = URL(fileURLWithPath: fontFile).deletingLastPathComponent().path
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fonts)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fonts) }

        // When, Then
        #expect(throws: PackError.unreadableFile(file: fonts)) { try sut.fontFiles(inPack: "shorts") }
    }

    @Test("a family the pack carries is taken from the pack before the machine's")
    func prefersPackFont() throws {
        // Given
        let sut = FontFinder(shaper: ShaperTable(installed: ["Inter"]), library: directory.library())

        // When
        let faces = try sut.faces(for: style(["Inter"]), from: origin("shorts"))

        // Then
        #expect(faces == [ShaperTable.face("Inter", .bold, file: fontFile)])
    }

    @Test("every family in the list that the pack carries or the machine has gives a face, in the list's order")
    func takesFamiliesFound() throws {
        // Given
        let sut = FontFinder(shaper: ShaperTable(installed: ["Apple SD Gothic Neo"]), library: directory.library())

        // When
        let packed = try sut.faces(for: style(["Missing", "Apple SD Gothic Neo", "Inter"]), from: origin("shorts"))
        let withoutPack = try sut.faces(for: style(["Inter", "Apple SD Gothic Neo"]), from: origin(nil))

        // Then
        #expect(packed == [ShaperTable.face("Apple SD Gothic Neo", .bold), ShaperTable.face("Inter", .bold, file: fontFile)])
        #expect(withoutPack == [ShaperTable.face("Apple SD Gothic Neo", .bold)])
    }

    @Test("a list with no family in the pack or on the machine stops, naming the families")
    func refusesMissingFamilies() throws {
        // Given
        let sut = FontFinder(shaper: ShaperTable(installed: []), library: directory.library())
        let place = Place(file: "shorts/shorts", components: [.key("font")])

        // When, Then
        let error = #expect(throws: TextError.self) {
            try sut.faces(for: style(["Missing", "Other"]), from: origin("shorts", place: place))
        }
        #expect(error?.description == #"""
            shorts/shorts: font (theme): no family of "Missing", "Other" is in its pack or on the machine
            """#)
    }

    // MARK: - Private
    private func origin(
        _ pack: String?,
        place: Place = .root
    ) -> FontListOrigin {
        FontListOrigin(place: place, kind: "theme", pack: pack)
    }

    private func style(_ families: [String]) -> CharacterStyle {
        CharacterStyle(
            families: families,
            weight: .bold,
            size: 40
        )
    }
}
