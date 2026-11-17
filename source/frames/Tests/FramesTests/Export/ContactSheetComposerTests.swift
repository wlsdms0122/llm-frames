//
//  ContactSheetComposerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

// The label face has an ascent of 0.8 and a descent of 0.2, so a label's line box is its size S, and the fake shaper
// sets each glyph 0.5 S wide.
@Suite("ContactSheetComposer Tests")
struct ContactSheetComposerTests {
    // MARK: - Property
    private let face = FontFace(file: "/Fonts/Label.ttc", name: "Label-Medium", ascent: 0.8, descent: 0.2)
    private let sut: ContactSheetComposer
    private let size = Size(width: 160, height: 90)

    // MARK: - Initializer
    init() {
        sut = ContactSheetComposer(shaper: Fixture.shaper, hasher: FileHashTable())
    }

    // MARK: - Test
    @Test(
        "the label size is the frame's longer side over 40, rounded, and at least 14",
        arguments: [
            (Size(width: 1920, height: 1080), 48.0),
            (Size(width: 1080, height: 1920), 48.0),
            (Size(width: 480, height: 270), 14.0),
            (Size(width: 620, height: 349), 16.0),
            (Size(width: 160, height: 90), 14.0)
        ] as [(Size, Double)]
    )
    func sizesLabelByFrame(
        frame: Size,
        expected: Double
    ) throws {
        // Given
        let cells = [cell(at: 0)]

        // When
        let sheet = try sut.sheet(of: cells, size: frame, columns: 1, face: face)

        // Then
        let label = try #require(labelGlyphs(of: sheet).first)
        #expect(label.runs.map(\.size) == [expected])
    }

    @Test("the label is white in the given face without a stroke, on a rounded translucent black box around its line")
    func setsLabelStyle() throws {
        // Given
        let cells = [cell(at: 0)]

        // When
        let sheet = try sut.sheet(of: cells, size: Size(width: 1920, height: 1080), columns: 1, face: face)

        // Then
        // At S 48, "0s" is 48 wide with 24 on each side, and its line box of 48 has 12 above and below.
        let label = try #require(labelGlyphs(of: sheet).first)
        let run = try #require(label.runs.first)
        #expect(label.size == Size(width: 96, height: 72))
        #expect(
            label.background == GlyphBackground(
                rectangle: Rectangle(x: 0, y: 0, width: 96, height: 72),
                radius: 48 * 0.3,
                color: Color(written: "#000000B3")
            )
        )
        #expect(label.stroke == nil)
        #expect(label.runs.count == 1)
        #expect(run.face == face.name)
        #expect(run.font.path == face.file)
        #expect(run.color == Color(written: "#FFFFFFFF"))
        #expect(run.glyphs.map(\.x) == [24, 48])
        #expect(run.glyphs.allSatisfy { abs($0.y - (12 + 0.8 * 48)) < 0.000001 })
    }

    @Test("each label's background has its top left half a label size from its frame's top left")
    func burnsLabelIntoFrame() throws {
        // Given
        let cells = (0..<4).map { cell(at: Double($0) * 0.5) }

        // When
        let sheet = try sut.sheet(of: cells, size: size, columns: 2, face: face)

        // Then
        let pictures = pictureRectangles(of: sheet)
        let labels = labelOrigins(of: sheet)
        try #require(labels.count == 4)
        for (picture, label) in zip(pictures, labels) {
            #expect(label == Point(x: picture.x + 7, y: picture.y + 7))
        }
        #expect(labelGlyphs(of: sheet).map { $0.runs.flatMap(\.glyphs).count } == [2, 4, 2, 4])
    }

    @Test("frames run left to right and then top down, a label size apart, with a label size around them")
    func placesCellsOnGrid() throws {
        // Given
        let cells = (0..<5).map { cell(at: Double($0)) }

        // When
        let sheet = try sut.sheet(of: cells, size: size, columns: 2, face: face)

        // Then
        let pictures = pictureRectangles(of: sheet)
        #expect(pictures.allSatisfy { $0.width == 160 && $0.height == 90 })
        #expect(pictures.map(\.x) == [14, 188, 14, 188, 14])
        #expect(pictures.map(\.y) == [14, 14, 118, 118, 222])
        #expect(sheet.size == Size(width: 14 + 160 + 14 + 160 + 14, height: 14 + 90 + 14 + 90 + 14 + 90 + 14))
        #expect(sheet.background == Color(written: "#202020FF"))
    }

    @Test("a single frame is that frame with its label and a label size around it")
    func framesSingleCell() throws {
        // Given
        let cells = [cell(at: 1)]

        // When
        let sheet = try sut.sheet(of: cells, size: Size(width: 1920, height: 1080), columns: 1, face: face)

        // Then
        #expect(pictureRectangles(of: sheet) == [Rectangle(x: 48, y: 48, width: 1920, height: 1080)])
        #expect(labelOrigins(of: sheet) == [Point(x: 72, y: 72)])
        #expect(sheet.size == Size(width: 48 + 1920 + 48, height: 48 + 1080 + 48))
    }

    @Test("a sheet with fewer cells than columns is only as wide as its cells")
    func narrowsToCells() throws {
        // Given
        let cells = [cell(at: 0), cell(at: 1)]

        // When
        let sheet = try sut.sheet(of: cells, size: size, columns: 6, face: face)

        // Then
        #expect(sheet.size.width == 14 + 160 + 14 + 160 + 14)
    }

    @Test(
        "a frame's label is its time rounded to the microsecond in its shortest form",
        arguments: [
            (2.5, "2.5s"),
            (0, "0s"),
            (0.1 + 0.2, "0.3s"),
            (1.0000004, "1s"),
            (12.3456789, "12.345679s")
        ]
    )
    func labelsTime(
        time: Double,
        expected: String
    ) {
        // Given
        let frame = SampledFrame(time: time, picture: .displayList(list()))

        // When
        let cell = ContactSheetCell(frame)

        // Then
        #expect(cell.label == expected)
    }

    // MARK: - Private
    private func cell(at time: Double) -> ContactSheetCell {
        ContactSheetCell(SampledFrame(time: time, picture: .displayList(list())))
    }

    private func list() -> DisplayList {
        DisplayList(size: size, background: Color(written: "#000000"), seed: 0, items: [])
    }

    private func pictureRectangles(of sheet: DisplayList) -> [Rectangle] {
        sheet.items.compactMap { item in
            guard case let .picture(picture) = item.content else { return nil }

            return picture.destination
        }
    }

    private func labelGlyphs(of sheet: DisplayList) -> [GlyphsItem] {
        sheet.items.compactMap { item in
            guard case let .glyphs(glyphs) = item.content else { return nil }

            return glyphs
        }
    }

    // Where each label's box, which its background fills, lies in the sheet.
    private func labelOrigins(of sheet: DisplayList) -> [Point] {
        sheet.items.compactMap { item in
            guard case .glyphs = item.content else { return nil }

            return Point(x: item.transform.tx, y: item.transform.ty)
        }
    }
}
