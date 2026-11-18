//
//  EvaluationReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("EvaluationReporter Tests")
struct EvaluationReporterTests {
    // MARK: - Property
    private let sut = EvaluationReporter()

    private let size = Size(width: 200, height: 100)
    private let black = Color(written: "#000000")
    private let transparent = Color(written: "#00000000")
    private let red = Color(written: "#FF0000")
    private let title = ItemOrigin(place: "clips[0]#title", id: "title", kind: "title")
    private let entry = ItemOrigin(place: "storyline[0]", id: nil, kind: "compound")
    private let nested = ItemOrigin(place: "storyline[0].media.storyline[2]", id: nil, kind: "video")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a turned item's bounds are the box of its turned corners, and a scaled one's its scaled rectangle")
    func boundsTransformedItems() throws {
        // Given
        let turned = DisplayItem(
            transform: AffineTransform(rotation: 90, about: Point(x: 100, y: 50)),
            content: .path(PathItem(filling: Rectangle(x: 80, y: 40, width: 40, height: 20), color: red)),
            origin: title
        )
        let scaled = DisplayItem(
            transform: AffineTransform(scale: 2, about: Point(x: 0, y: 0)),
            content: .path(PathItem(filling: Rectangle(x: 10, y: 10, width: 20, height: 5), color: red))
        )

        // When
        let report = sut.report(of: list([turned, scaled]), at: 0)

        // Then
        let bounds = report.items.map(\.bounds)
        #expect(isClose(try #require(bounds[0]), Rectangle(x: 90, y: 30, width: 20, height: 40)))
        #expect(bounds[1] == Rectangle(x: 20, y: 20, width: 40, height: 10))
    }

    @Test("bounds are cut by the mask, the reveal and the output frame, and an item they leave nothing of has none")
    func cutsBoundsByMasks() {
        // Given
        let fill = PathItem(filling: Rectangle(x: 0, y: 0, width: 100, height: 100), color: red)
        let masked = DisplayItem(mask: mask(Rectangle(x: 50, y: 20, width: 100, height: 100)), content: .path(fill))
        let revealed = DisplayItem(
            transform: AffineTransform(translation: Point(x: 150, y: 0)),
            reveal: Rectangle(x: 0, y: 0, width: 25, height: 100),
            content: .path(fill)
        )
        let hidden = DisplayItem(mask: mask(Rectangle(x: 300, y: 0, width: 10, height: 10)), content: .path(fill))

        // When
        let report = sut.report(of: list([masked, revealed, hidden]), at: 0)

        // Then
        #expect(report.items.map(\.bounds) == [
            Rectangle(x: 50, y: 20, width: 50, height: 80),
            Rectangle(x: 150, y: 0, width: 25, height: 100),
            nil
        ])
    }

    @Test("a turned item under a mask is bounded by what the mask leaves of its turned shape, not of its box")
    func cutsTurnedShapeByMask() throws {
        // Given
        // A 20 x 20 square turned 45 degrees about its centre (50, 50) is a diamond reaching 50 ± 14.14 on each axis.
        let diamond = DisplayItem(
            transform: AffineTransform(rotation: 45, about: Point(x: 50, y: 50)),
            mask: mask(Rectangle(x: 0, y: 0, width: 50, height: 50)),
            content: .path(PathItem(filling: Rectangle(x: 40, y: 40, width: 20, height: 20), color: red))
        )

        // When
        let report = sut.report(of: list([diamond]), at: 0)

        // Then
        let reach = 10 * 2.0.squareRoot()
        let bounds = try #require(report.items.first?.bounds)
        #expect(isClose(bounds, Rectangle(x: 50 - reach, y: 50 - reach, width: reach, height: reach)))
    }

    @Test("a nested list's items are reported in its place, carried by its picture and named by their own clips")
    func flattensNestedList() throws {
        // Given
        let inner = DisplayList(size: Size(width: 100, height: 50), background: red, seed: 0, items: [
            DisplayItem(
                content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 50, height: 25), color: black)),
                origin: nested
            ),
            DisplayItem(
                content: .path(PathItem(filling: Rectangle(x: 50, y: 25, width: 50, height: 25), color: black))
            )
        ])
        let picture = PictureItem(
            source: .displayList(inner),
            rectangle: Rectangle(x: 0, y: 0, width: 100, height: 50),
            destination: Rectangle(x: 0, y: 0, width: 100, height: 50)
        )
        let item = DisplayItem(
            transform: AffineTransform(scale: 2, about: Point(x: 0, y: 0)),
            opacity: 0.5,
            content: .picture(picture),
            origin: entry
        )

        // When
        let report = sut.report(of: list([item], background: black), at: 0)

        // Then
        // The nested background and the fill without a clip of its own are the compound clip's picture.
        #expect(report.items == [
            EvaluationItem(origin: nil, bounds: Rectangle(x: 0, y: 0, width: 200, height: 100), opacity: 1),
            EvaluationItem(origin: entry, bounds: Rectangle(x: 0, y: 0, width: 200, height: 100), opacity: 0.5),
            EvaluationItem(origin: nested, bounds: Rectangle(x: 0, y: 0, width: 100, height: 50), opacity: 0.5),
            EvaluationItem(origin: entry, bounds: Rectangle(x: 100, y: 50, width: 100, height: 50), opacity: 0.5)
        ])
    }

    @Test("a nested list shows only the source rect its picture draws, scaled into the picture's destination")
    func cutsNestedListBySourceRect() {
        // Given
        let inner = DisplayList(size: Size(width: 100, height: 100), background: transparent, seed: 0, items: [
            DisplayItem(
                content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 100, height: 100), color: black)),
                origin: nested
            )
        ])
        let picture = PictureItem(
            source: .displayList(inner),
            rectangle: Rectangle(x: 50, y: 50, width: 50, height: 25),
            destination: Rectangle(x: 0, y: 0, width: 200, height: 100)
        )

        // When
        let report = sut.report(of: list([DisplayItem(content: .picture(picture), origin: entry)]), at: 0)

        // Then
        #expect(report.items == [
            EvaluationItem(origin: nested, bounds: Rectangle(x: 0, y: 0, width: 200, height: 100), opacity: 1)
        ])
    }

    @Test(
        "a stroked rect covers half its stroke to each side of its edge, and a filled polyline its points and its stroke"
    )
    func boundsPaths() {
        // Given
        let stroke = PathStroke(width: 4, color: red, join: .miter, cap: .butt, start: .none, end: .arrow)
        let rect = DisplayItem(content: .path(PathItem(
            geometry: .rect(Rectangle(x: 20, y: 20, width: 40, height: 30), radius: 4),
            fill: nil,
            stroke: stroke
        )))
        let polyline = DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 100, y: 10), Point(x: 160, y: 10), Point(x: 160, y: 50)], isClosed: false),
            fill: black,
            stroke: stroke
        )))

        // When
        let report = sut.report(of: list([rect, polyline]), at: 0)

        // Then
        // The arrowhead at (160, 50) is 16 long and 16 wide, its base from x = 152 to 168.
        #expect(report.items.map(\.bounds) == [
            Rectangle(x: 18, y: 18, width: 44, height: 34),
            Rectangle(x: 100, y: 8, width: 68, height: 42)
        ])
    }

    @Test("a resolved document is evaluated at the time, and its clips report their places, ids, kinds and bounds")
    func reportsResolvedDocument() throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "id": "intro", "media": "/abs/short.mp4", "in": 0, "out": 4,
                               "connected": [ { "shape": "rect", "fill": "#FFD43B80", "area": [100, 200, 300, 400] } ] } ] }
            """#)

        // When
        let report = try sut.report(of: document, at: 1.5)

        // Then
        // The connected fill has no parent, so its area is in output pixels.
        let frame = Rectangle(x: 0, y: 0, width: 1080, height: 1920)
        #expect(report.time == 1.5)
        #expect(report.size == Size(width: 1080, height: 1920))
        #expect(report.items == [
            EvaluationItem(origin: nil, bounds: frame, opacity: 1),
            EvaluationItem(
                origin: ItemOrigin(place: "storyline[0]#intro", id: "intro", kind: "video"),
                bounds: frame,
                opacity: 1
            ),
            EvaluationItem(
                origin: ItemOrigin(place: "storyline[0]#intro.connected[0]", id: nil, kind: "rect"),
                bounds: Rectangle(x: 100, y: 200, width: 300, height: 400),
                opacity: 1
            )
        ])
    }

    @Test("a clip used as a track matte reports no item, and the clip it cuts is bounded as without it, and so located")
    func leavesTrackMatteOut() throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 4 } ],
              "clips": [
                { "id": "m", "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 50, 50], "at": [0, 4] },
                { "id": "a", "shape": "rect", "fill": "#FFD43B80", "area": [100, 200, 300, 400], "at": [0, 4],
                  "trackMatte": { "clip": "m", "mode": "alpha" } } ] }
            """#)

        // When
        let report = try sut.report(of: document, at: 1.5)
        let hits = try LocationReporter().report(of: document, at: 1.5, point: Point(x: 25, y: 25)).hits

        // Then
        #expect(report.items.compactMap { $0.origin?.id } == ["a"])
        #expect(report.items.last?.bounds == Rectangle(x: 100, y: 200, width: 300, height: 400))
        #expect(hits.allSatisfy { $0.origin?.id != "m" })
    }

    @Test("a sequence stops on a time outside [0, duration) as still does", arguments: [-0.5, 4])
    func stopsOnTimeOutsideSequence(time: Double) throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "storyline": [ { "solid": "#FF8000", "duration": 4 } ] }
            """#)

        // When, Then
        #expect(throws: ExportError.timeOutside(option: "--at", time: time, end: 4, kind: "sequence")) {
            try sut.report(of: document, at: time)
        }
    }

    @Test("a compound clip a connected clip shows names its own clips in the clip's place")
    func reportsCompoundInClip() throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 4,
                               "connected": [ { "media": { "kind": "sequence",
                                                           "storyline": [ { "media": "/abs/page.png", "duration": 2,
                                                               "connected": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [100, 100, 200, 100] } ] } ] },
                                                "at": [0, 2] } ] } ] }
            """#)

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        // Only the nested background, drawn by no clip of the nested sequence, is the compound clip's picture.
        let places = report.items.compactMap(\.origin?.place)
        #expect(places.contains("storyline[0].connected[0].media.storyline[0]"))
        #expect(places.contains("storyline[0].connected[0].media.storyline[0].connected[0]"))
        #expect(places.filter { $0 == "storyline[0].connected[0]" }.count == 1)
    }

    @Test("the machine output is the evaluate object FRAMES-23 gives, bounds and opacity rounded to a millionth")
    func writesMachineOutput() throws {
        // Given
        let turned = DisplayItem(
            transform: AffineTransform(rotation: 90, about: Point(x: 100, y: 50)),
            opacity: 0.1 + 0.2,
            content: .path(PathItem(filling: Rectangle(x: 80, y: 40, width: 40, height: 20), color: red)),
            origin: title
        )
        let report = sut.report(of: list([turned], background: black), at: 1.0000004)

        // When
        let text = JSONWriter().write(report.machineOutput)

        // Then
        #expect(text == #"""
            {
              "evaluate": "1.0.0",
              "time": 1,
              "size": [200, 100],
              "items": [
                {
                  "place": null,
                  "id": null,
                  "kind": null,
                  "bounds": [0, 0, 200, 100],
                  "opacity": 1
                },
                {
                  "place": "clips[0]#title",
                  "id": "title",
                  "kind": "title",
                  "bounds": [90, 30, 20, 40],
                  "opacity": 0.3
                }
              ]
            }

            """#)
    }

    // MARK: - Private
    // One sharp `add` mask of the rectangle in output pixels.
    private func mask(_ rectangle: Rectangle) -> [ItemMask] {
        [ItemMask(geometry: .rect(rectangle, radius: 0), transform: .identity, feather: 0, isInverted: false, mode: .add)]
    }

    private func list(
        _ items: [DisplayItem],
        background: Color? = nil
    ) -> DisplayList {
        DisplayList(size: size, background: background ?? transparent, seed: 0, items: items)
    }

    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        [rectangle.x - other.x, rectangle.y - other.y, rectangle.width - other.width, rectangle.height - other.height]
            .allSatisfy { abs($0) < 1e-9 }
    }
}
