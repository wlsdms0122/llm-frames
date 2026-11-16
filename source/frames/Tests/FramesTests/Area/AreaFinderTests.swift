//
//  AreaFinderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("AreaFinder Tests")
struct AreaFinderTests {
    // MARK: - Property
    private let screen = Picture(
        name: "/abs/screen.mp4",
        source: .mediaFile(MediaFile(path: "/abs/screen.mp4")),
        size: Size(width: 1206, height: 2622)
    )
    private let place = Place.root.appending(key: "area")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a rectangle is the area as written, and takes no padding")
    func takesRectangleAsWritten() throws {
        // Given
        let sut = AreaFinder(ocr: OCRTable([:]))

        // When
        let found = try find(.rectangle(rectangle(10, 20, 100, 50)), with: sut)

        // Then
        #expect(found == FoundArea(
            rectangle: rectangle(10, 20, 100, 50),
            target: rectangle(10, 20, 100, 50),
            isBand: false,
            mediaTime: 1,
            lines: []
        ))
    }

    @Test("an area partly outside the picture is cut to it, and one wholly outside stops")
    func cutsAreaToPicture() throws {
        // Given
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: [line("Back", 100, 4, 200, 40)]))

        // When
        let partly = try find(.rectangle(rectangle(1100, -10, 200, 100)), with: sut)
        let padded = try find(.text("Back", nth: nil), with: sut)

        // Then
        #expect(partly.rectangle == rectangle(1100, 0, 106, 90))
        #expect(padded.rectangle == rectangle(86, 0, 228, 58))
        #expect(padded.target == rectangle(100, 4, 200, 40))
        let error = #expect(throws: AreaError.self) { try find(.rectangle(rectangle(2000, 0, 10, 10)), with: sut) }
        #expect(error?.description == "area (box): the area [2000, 0, 10, 10] lies wholly outside its picture of 1206x2622")
    }

    @Test("a text area is the whole line that contains the text, grown by the padding, its target before padding")
    func findsWholeLine() throws {
        // Given
        let lines = [line("Settings", 100, 100, 300, 50), line("Sign in to continue", 100, 200, 400, 50)]
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: lines))

        // When
        let found = try find(.text("in to", nth: nil), with: sut)

        // Then
        #expect(found == FoundArea(
            rectangle: rectangle(86, 186, 428, 78),
            target: rectangle(100, 200, 400, 50),
            isBand: false,
            mediaTime: 1,
            lines: [lines[1]]
        ))
    }

    @Test(
        "text is compared with whitespace removed on both sides",
        arguments: [("Signin", "Sign in"), ("Sign  in", "Signin"), ("결제 하기", "결제하기 버튼")]
    )
    func comparesWithoutWhitespace(
        text: String,
        recognised: String
    ) throws {
        // Given
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: [line(recognised, 100, 200, 400, 50)]))

        // When
        let found = try find(.text(text, nth: nil), with: sut)

        // Then
        #expect(found.target == rectangle(100, 200, 400, 50))
    }

    @Test("text without nth that matches more than one line stops and lists every match")
    func refusesAmbiguousText() throws {
        // Given
        let lines = [line("Delete", 100, 900, 200, 40), line("Delete all", 100, 300, 300, 40)]
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: lines))

        // When, Then
        let error = #expect(throws: AreaError.self) { try find(.text("Delete", nth: nil), with: sut) }
        #expect(error?.description == #"""
            area (box): "Delete" matches 2 lines: [100, 300, 300, 40] "Delete all", [100, 900, 200, 40] "Delete". \#
            Give nth to pick one
            """#)
    }

    @Test(
        "nth counts matches top to bottom by row and left to right in a row, where close centres make one row",
        arguments: [(0, 100.0), (1, 500.0), (2, 900.0), (3, 100.0)]
    )
    func countsNthByRow(
        nth: Int,
        x: Double
    ) throws {
        // Given
        let lines = [
            line("Item", 500, 100, 200, 40),
            line("Item", 100, 115, 200, 40),
            line("Item", 900, 130, 200, 60),
            line("Item", 100, 300, 200, 40)
        ]
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: lines))

        // When
        let found = try find(.text("Item", nth: nth), with: sut)

        // Then
        #expect(found.target.x == x)
    }

    @Test("text that matches no line, or fewer lines than nth asks, stops naming the media, the text and the nth")
    func refusesMissingText() throws {
        // Given
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: [line("Item", 100, 100, 200, 40)]))

        // When, Then
        let none = #expect(throws: AreaError.self) { try find(.text("Cart", nth: nil), with: sut) }
        let nth = #expect(throws: AreaError.self) { try find(.text("Item", nth: 1), with: sut) }
        #expect(none?.description == #"area (box): no line of "/abs/screen.mp4" at media second 1 contains "Cart""#)
        #expect(nth?.description == #"""
            area (box): 1 line of "/abs/screen.mp4" at media second 1 contains "Item", so there is no line 1 \#
            (counted from 0)
            """#)
    }

    @Test("a from and to area holds both lines and every line whose centre lies between their top and bottom")
    func findsRange() throws {
        // Given
        let lines = [
            line("Paid", 100, 300, 200, 40),
            line("Total", 100, 100, 200, 40),
            line("Tax", 700, 200, 300, 40),
            line("Footer", 100, 330, 900, 40)
        ]
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: lines))

        // When
        let found = try find(.range(from: "Total", fromNth: nil, to: "Paid", toNth: nil), with: sut, padding: 0)

        // Then
        #expect(found.rectangle == rectangle(100, 100, 900, 240))
        #expect(Set(found.lines.map(\.text)) == ["Total", "Paid", "Tax"])
    }

    @Test("each end of a from and to area stops on its own when it is ambiguous or missing")
    func refusesRangeEnds() throws {
        // Given
        let lines = [line("Total", 100, 100, 200, 40), line("Total", 100, 500, 200, 40)]
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: lines))

        // When, Then
        let ambiguous = #expect(throws: AreaError.self) {
            try find(.range(from: "Total", fromNth: nil, to: "Total", toNth: 1), with: sut)
        }
        let missing = #expect(throws: AreaError.self) {
            try find(.range(from: "Total", fromNth: 0, to: "Paid", toNth: nil), with: sut)
        }
        #expect(ambiguous?.description.hasPrefix(#"area (box): "Total" matches 2 lines"#) == true)
        #expect(missing?.description == #"area (box): no line of "/abs/screen.mp4" at media second 1 contains "Paid""#)
    }

    @Test("a band is the full width of the picture between the top and bottom of its inner area, padding included")
    func widensBand() throws {
        // Given
        let sut = AreaFinder(ocr: OCRTable(file: "/abs/screen.mp4", lines: [line("Total", 100, 100, 200, 40)]))

        // When
        let text = try find(.band(.text("Total", nth: nil)), with: sut)
        let written = try find(.band(.rectangle(rectangle(10, 500, 20, 30))), with: sut)

        // Then
        #expect(text.rectangle == rectangle(0, 86, 1206, 68))
        #expect(text.target == rectangle(100, 100, 200, 40))
        #expect(text.isBand)
        #expect(written.rectangle == rectangle(0, 500, 1206, 30))
    }

    @Test("text is searched in the frame shown at the media time asked")
    func readsFrameAtMediaTime() throws {
        // Given
        let sut = AreaFinder(ocr: OCRTable([
            "/abs/screen.mp4": [
                (from: 0, lines: [line("Total", 100, 100, 200, 40)]),
                (from: 2, lines: [line("Total", 100, 700, 200, 40)])
            ]
        ]))

        // When
        let early = try sut.area(.text("Total", nth: nil), in: screen, atMediaTime: 1.9, padding: 0, place: place, kind: "box")
        let late = try sut.area(.text("Total", nth: nil), in: screen, atMediaTime: 2, padding: 0, place: place, kind: "box")

        // Then
        #expect(early.target.y == 100)
        #expect(late.target.y == 700)
        #expect(late.mediaTime == 2)
    }

    @Test(
        "a picture that is drawn, not read, takes no text area",
        arguments: [
            (
                PictureSource.document,
                #"area (box): "pack/intro" is drawn, not read, so it takes no text area. "#
                    + "Point at text inside it from the document that draws it"
            ),
            (
                PictureSource.solid,
                "area (box): the clip's picture is a solid, not a media file, so it is drawn, not read, and takes no "
                    + "text area"
            )
        ]
    )
    func refusesTextInDrawnPicture(
        source: PictureSource,
        message: String
    ) throws {
        // Given
        let sut = AreaFinder(ocr: OCRTable([:]))
        let picture = Picture(name: "pack/intro", source: source, size: Size(width: 1080, height: 1920))

        // When
        let rectangle = try sut.area(.rectangle(rectangle(0, 0, 10, 10)), in: picture, atMediaTime: 0, padding: 14, place: place, kind: "box")

        // Then
        #expect(rectangle.rectangle == self.rectangle(0, 0, 10, 10))
        let error = #expect(throws: AreaError.self) {
            try sut.area(.text("a", nth: nil), in: picture, atMediaTime: 0, padding: 14, place: place, kind: "box")
        }
        #expect(error?.description == message)
    }

    // MARK: - Private
    private func find(
        _ form: AreaForm,
        with sut: AreaFinder,
        padding: Double = 14
    ) throws -> FoundArea {
        try sut.area(form, in: screen, atMediaTime: 1, padding: padding, place: place, kind: "box")
    }

    private func rectangle(
        _ x: Double,
        _ y: Double,
        _ width: Double,
        _ height: Double
    ) -> Rectangle {
        Rectangle(x: x, y: y, width: width, height: height)
    }

    private func line(
        _ text: String,
        _ x: Double,
        _ y: Double,
        _ width: Double,
        _ height: Double
    ) -> RecognisedLine {
        RecognisedLine(text: text, rectangle: rectangle(x, y, width, height))
    }
}
