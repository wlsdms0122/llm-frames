//
//  ContactSheetComposerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("ContactSheetComposer Tests")
struct ContactSheetComposerTests {
    // MARK: - Property
    private let sut = ContactSheetComposer(shaper: Fixture.shaper, library: Fixture.library, hasher: FileHashTable())
    private let size = Size(width: 160, height: 90)

    // MARK: - Initializer
    // MARK: - Test
    @Test("cells run left to right and then top down, a gap apart, with the padding around them")
    func placesCellsOnGrid() throws {
        // Given
        let cells = (0..<5).map { cell(at: Double($0)) }

        // When
        let sheet = try sut.sheet(of: cells, size: size, columns: 2)

        // Then
        // The base theme's `layout.gap` and `layout.padding` are both 40 at its width of 1206, so 5 at 160.
        let pictures = pictureRectangles(of: sheet)
        let band = pictures[2].y - pictures[0].maxY - 5
        #expect(pictures.allSatisfy { $0.width == 160 && $0.height == 90 })
        #expect(pictures.map(\.x) == [5, 170, 5, 170, 5])
        #expect(pictures.map(\.y) == [5, 5, 5 + 95 + band, 5 + 95 + band, 5 + (95 + band) * 2])
        #expect(band > 5 && band.rounded() == band)
        #expect(sheet.size == Size(width: 5 + 160 + 5 + 160 + 5, height: 5 + (90 + band) * 3 + 5 * 2 + 5))
        #expect(sheet.background == Color(written: "#FFFFFF"))
    }

    @Test("a sheet with fewer cells than columns is only as wide as its cells")
    func narrowsToCells() throws {
        // Given
        let cells = [cell(at: 0), cell(at: 1)]

        // When
        let sheet = try sut.sheet(of: cells, size: size, columns: 6)

        // Then
        #expect(sheet.size.width == 5 + 160 + 5 + 160 + 5)
    }

    @Test("each label is centred on the band under its picture, in the base theme's label style")
    func centresLabelOnBand() throws {
        // Given
        let cells = (0..<4).map { cell(at: Double($0) * 0.5) }

        // When
        let sheet = try sut.sheet(of: cells, size: size, columns: 2)

        // Then
        let pictures = pictureRectangles(of: sheet)
        let frames = labelFrames(of: sheet)
        let labels = labelGlyphs(of: sheet)
        try #require(frames.count == 4)
        for (picture, frame) in zip(pictures, frames) {
            #expect(abs(frame.center.x - picture.center.x) < 0.000001)
            #expect(frame.y > picture.maxY)
        }
        #expect(frames[0].maxY < pictures[2].y - 5)
        #expect(abs((frames[0].y - pictures[0].maxY) - (pictures[2].y - 5 - frames[0].maxY)) < 0.000001)
        #expect(labels.allSatisfy { $0.background?.color == Color(written: "#ED2929") })
        #expect(labels.allSatisfy { $0.runs.allSatisfy { $0.color == Color(written: "#FFFFFF") } })
        #expect(labels.map { $0.runs.flatMap(\.glyphs).count } == [2, 4, 2, 4])
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

    // A label's box in the sheet: its background fills the box, which its transform moves into place.
    private func labelFrames(of sheet: DisplayList) -> [Rectangle] {
        sheet.items.compactMap { item in
            guard case let .glyphs(glyphs) = item.content, let box = glyphs.background?.rectangle else { return nil }

            return Rectangle(x: item.transform.tx, y: item.transform.ty, width: box.width, height: box.height)
        }
    }
}
