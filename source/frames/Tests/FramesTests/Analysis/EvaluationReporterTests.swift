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
        let doubled = AffineTransform(scale: 2, about: Point(x: 0, y: 0))
        #expect(report.items == [
            EvaluationItem(
                origin: nil,
                item: .background,
                bounds: Rectangle(x: 0, y: 0, width: 200, height: 100),
                opacity: 1,
                transform: .identity,
                rect: Rectangle(x: 0, y: 0, width: 200, height: 100)
            ),
            EvaluationItem(
                origin: entry,
                item: .background,
                bounds: Rectangle(x: 0, y: 0, width: 200, height: 100),
                opacity: 0.5,
                transform: doubled,
                rect: Rectangle(x: 0, y: 0, width: 100, height: 50)
            ),
            EvaluationItem(
                origin: nested,
                item: .path,
                bounds: Rectangle(x: 0, y: 0, width: 100, height: 50),
                opacity: 0.5,
                transform: doubled,
                rect: Rectangle(x: 0, y: 0, width: 50, height: 25)
            ),
            EvaluationItem(
                origin: entry,
                item: .path,
                bounds: Rectangle(x: 100, y: 50, width: 100, height: 50),
                opacity: 0.5,
                transform: doubled,
                rect: Rectangle(x: 50, y: 25, width: 50, height: 25)
            )
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
        // The source rect's top left lands on the destination's, four times as large.
        #expect(report.items == [
            EvaluationItem(
                origin: nested,
                item: .path,
                bounds: Rectangle(x: 0, y: 0, width: 200, height: 100),
                opacity: 1,
                transform: AffineTransform(a: 4, b: 0, c: 0, d: 4, tx: -200, ty: -200),
                rect: Rectangle(x: 0, y: 0, width: 100, height: 100)
            )
        ])
    }

    @Test(
        "a stroked rect covers half its stroke to each side of its edge, and a filled polyline its points and its stroke"
    )
    func boundsPaths() {
        // Given
        let stroke = PathStroke(width: 4, paint: .color(red), join: .miter, cap: .butt, start: .none, end: .arrow)
        let rect = DisplayItem(content: .path(PathItem(
            geometry: .rect(Rectangle(x: 20, y: 20, width: 40, height: 30), radius: 4),
            fill: nil,
            stroke: stroke
        )))
        let polyline = DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 100, y: 10), Point(x: 160, y: 10), Point(x: 160, y: 50)], isClosed: false),
            fill: .color(black),
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

    @Test("a nested list's items report the maps of the pictures holding them composed with their own, and their rects")
    func reportsNestedTransforms() {
        // Given
        let inner = DisplayList(size: Size(width: 100, height: 50), background: red, seed: 0, items: [
            DisplayItem(
                transform: AffineTransform(translation: Point(x: 10, y: 0)),
                content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 20, height: 10), color: black)),
                origin: nested
            ),
            DisplayItem(
                transform: AffineTransform(translation: Point(x: 5, y: 5)),
                reveal: Rectangle(x: 0, y: 0, width: 100, height: 50),
                content: .adjust(AdjustItem(filter: []))
            )
        ])
        let picture = PictureItem(
            source: .displayList(inner),
            rectangle: nil,
            destination: Rectangle(x: 20, y: 10, width: 50, height: 25)
        )
        let item = DisplayItem(
            transform: AffineTransform(scale: 2, about: Point(x: 0, y: 0)),
            content: .picture(picture),
            origin: entry
        )

        // When
        let report = sut.report(of: list([item], background: black), at: 0)

        // Then
        // The picture maps the list's pixels (x, y) to (20 + x / 2, 10 + y / 2) and its transform doubles that, so the
        // list's pixels land at (40 + x, 20 + y), and the path's own at (50 + x, 20 + y). The adjustment's own
        // transform carries only its reveal.
        let list = AffineTransform(translation: Point(x: 40, y: 20))
        #expect(report.items.map(\.transform) == [
            .identity,
            list,
            AffineTransform(translation: Point(x: 50, y: 20)),
            list
        ])
        #expect(report.items.map(\.rect) == [
            Rectangle(x: 0, y: 0, width: 200, height: 100),
            Rectangle(x: 0, y: 0, width: 100, height: 50),
            Rectangle(x: 0, y: 0, width: 20, height: 10),
            Rectangle(x: 0, y: 0, width: 100, height: 50)
        ])
    }

    @Test("a turned, masked picture reports its whole destination as its rect, and its bounds only what shows")
    func reportsPictureRect() throws {
        // Given
        let destination = Rectangle(x: 80, y: 40, width: 40, height: 20)
        let item = DisplayItem(
            transform: AffineTransform(rotation: 90, about: Point(x: 100, y: 50)),
            mask: mask(Rectangle(x: 0, y: 0, width: 100, height: 100)),
            content: .picture(PictureItem(source: .media(frame), rectangle: nil, destination: destination)),
            origin: title
        )

        // When
        let report = sut.report(of: list([item]), at: 0)

        // Then
        let reported = try #require(report.items.first)
        #expect(reported.rect == destination)
        #expect(isClose(reported.transform, AffineTransform(rotation: 90, about: Point(x: 100, y: 50))))
        #expect(isClose(try #require(reported.bounds), Rectangle(x: 90, y: 30, width: 10, height: 40)))
    }

    @Test("a path's rect is the box of its geometry without its stroke, a polyline's the box of its points")
    func reportsPathRect() {
        // Given
        let stroke = PathStroke(width: 4, paint: .color(red), join: .miter, cap: .butt, start: .none, end: .arrow)
        let ellipse = DisplayItem(content: .path(PathItem(
            geometry: .ellipse(Rectangle(x: 20, y: 20, width: 40, height: 30)),
            fill: nil,
            stroke: stroke
        )))
        let polyline = DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 100, y: 10), Point(x: 160, y: 10), Point(x: 160, y: 50)], isClosed: false),
            fill: nil,
            stroke: stroke
        )))

        // When
        let report = sut.report(of: list([ellipse, polyline]), at: 0)

        // Then
        #expect(report.items.map(\.rect) == [
            Rectangle(x: 20, y: 20, width: 40, height: 30),
            Rectangle(x: 100, y: 10, width: 60, height: 40)
        ])
    }

    @Test("a whole title's glyphs item reports its text box and covers it grown by its stroke with its highlights")
    func reportsTitleGlyphs() throws {
        // Given
        let highlight = DrawnHighlight(
            rects: [Rectangle(x: -10, y: 0, width: 30, height: 20)],
            radius: 0,
            color: red,
            bands: nil
        )
        let glyphs = GlyphsItem(
            size: Size(width: 100, height: 40),
            runs: [run(stroke: TextStroke(width: 6, color: black), highlight: highlight)],
            background: nil
        )
        let item = DisplayItem(
            transform: AffineTransform(translation: Point(x: 20, y: 20)),
            content: .glyphs(glyphs),
            origin: title
        )

        // When
        let report = sut.report(of: list([item]), at: 0)
        let hits = LocationReporter().report(of: list([item]), point: Point(x: 12, y: 25)).hits

        // Then
        // Half the stroke reaches 3 past the text box, and the highlight 10 past its left edge.
        let reported = try #require(report.items.first)
        #expect(reported.rect == Rectangle(x: 0, y: 0, width: 100, height: 40))
        #expect(reported.transform == AffineTransform(translation: Point(x: 20, y: 20)))
        #expect(reported.bounds == Rectangle(x: 10, y: 17, width: 113, height: 46))
        #expect(hits.map(\.item) == [.glyphs])
    }

    @Test("a unit's item reports and covers its extent, and a title's background alone its background or nothing")
    func reportsUnitGlyphs() {
        // Given
        let size = Size(width: 100, height: 40)
        let unit = GlyphsItem(
            size: size,
            runs: [run(stroke: nil, highlight: nil)],
            layer: .fills,
            unitBox: Rectangle(x: 0, y: 0, width: 50, height: 40),
            extent: Rectangle(x: 5, y: 10, width: 30, height: 20),
            background: nil
        )
        let background = GlyphsItem(
            size: size,
            runs: [],
            background: GlyphBackground(rectangle: Rectangle(x: 0, y: 0, width: 100, height: 40), radius: 0, color: red)
        )
        let bare = GlyphsItem(size: size, runs: [], background: nil)

        // When
        let report = sut.report(of: list([
            DisplayItem(content: .glyphs(unit), origin: title),
            DisplayItem(content: .glyphs(background), origin: title),
            DisplayItem(content: .glyphs(bare), origin: title)
        ]), at: 0)

        // Then
        #expect(report.items.map(\.bounds) == [
            Rectangle(x: 5, y: 10, width: 30, height: 20),
            Rectangle(x: 0, y: 0, width: 100, height: 40),
            nil
        ])
        #expect(report.items.map(\.rect) == [
            Rectangle(x: 5, y: 10, width: 30, height: 20),
            Rectangle(x: 0, y: 0, width: 100, height: 40),
            Rectangle(x: 0, y: 0, width: 100, height: 40)
        ])
    }

    @Test("a unit's item reports the characters of the unit its origin names, whatever its place among the title's items")
    func reportsUnitByOrigin() throws {
        // Given
        let document = try resolved(titled(#"{ "title": "ab cd", "animation": { "preset": "frames/fade", "by": "word" } }"#))
        let titles = document.titles(at: 1)
        let place = try #require(titles.keys.first)
        let fills = GlyphsItem(
            size: Size(width: 100, height: 40),
            runs: [run(stroke: nil, highlight: nil)],
            layer: .fills,
            unitBox: Rectangle(x: 0, y: 0, width: 50, height: 40),
            extent: Rectangle(x: 0, y: 0, width: 50, height: 40),
            background: nil
        )
        let origin = { (unit: Int) in ItemOrigin(place: place, id: "t", kind: "title", unit: unit) }

        // When
        let report = sut.report(
            of: list([
                DisplayItem(content: .glyphs(fills), origin: origin(1)),
                DisplayItem(content: .glyphs(fills), origin: origin(0))
            ]),
            titles: titles,
            at: 1
        )

        // Then
        #expect(report.items.map { $0.characters?.map(\.text) } == [["c", "d"], ["a", "b", " "]])
    }

    @Test("a resolved document is evaluated at the time, its clips reporting places, ids, kinds, bounds and rects")
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
            EvaluationItem(
                origin: nil,
                item: .background,
                bounds: frame,
                opacity: 1,
                transform: .identity,
                rect: frame
            ),
            EvaluationItem(
                origin: ItemOrigin(place: "storyline[0]#intro", id: "intro", kind: "video"),
                item: .picture,
                bounds: frame,
                opacity: 1,
                transform: .identity,
                rect: frame
            ),
            EvaluationItem(
                origin: ItemOrigin(place: "storyline[0]#intro.connected[0]", id: nil, kind: "rect"),
                item: .path,
                bounds: Rectangle(x: 100, y: 200, width: 300, height: 400),
                opacity: 1,
                transform: .identity,
                rect: Rectangle(x: 100, y: 200, width: 300, height: 400)
            )
        ])
    }

    @Test("each item names the FRAMES-20 item kind it draws, and the background is a background item, in both commands")
    func namesItemKinds() throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920], "background": "#101010" },
              "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 4 } ],
              "clips": [
                { "at": [0, 4], "title": "Top", "style": "title" },
                { "at": [0, 4], "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 50, 50] },
                { "at": [0, 4], "adjust": "mine/grade" } ] }
            """#)

        // When
        let report = try sut.report(of: document, at: 1.5)
        let hits = try LocationReporter().report(of: document, at: 1.5, point: Point(x: 25, y: 25)).hits

        // Then
        #expect(report.items.map(\.item) == [.background, .picture, .glyphs, .path, .adjust])
        #expect(report.items.map { $0.origin?.kind } == [nil, "video", "title", "rect", "adjustment"])
        #expect(hits.map(\.item) == [.adjust, .path, .picture, .background])
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

    @Test("the machine output is the evaluate object FRAMES-23 gives, its numbers rounded to a millionth")
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
                  "item": "background",
                  "bounds": [0, 0, 200, 100],
                  "opacity": 1,
                  "transform": [1, 0, 0, 1, 0, 0],
                  "rect": [0, 0, 200, 100],
                  "characters": null
                },
                {
                  "place": "clips[0]#title",
                  "id": "title",
                  "kind": "title",
                  "item": "path",
                  "bounds": [90, 30, 20, 40],
                  "opacity": 0.3,
                  "transform": [0, 1, -1, 0, 150, -50],
                  "rect": [80, 40, 40, 20],
                  "characters": null
                }
              ],
              "texts": []
            }

            """#)
    }

    @Test("a title by unit mid entrance reports each unit's characters on its fills item in the text box, and its text box's map without their motion")
    func reportsUnitCharacters() throws {
        // Given
        let rise = AnimationPreset(
            description: "",
            entrance: AnimationSpan(
                length: 1,
                span: Span(ease: .linear, keys: [SpanKey(t: 0, values: [.y: 1]), SpanKey(t: 1, values: [.y: 0])])
            ),
            loop: nil,
            exit: nil
        )
        let animated = try resolved(
            titled(#"{ "title": "ab cd", "animation": { "preset": "mine/rise", "by": "character", "stagger": 0.25 } }"#),
            animations: ["mine/rise": rise]
        )
        let still = try resolved(titled(#"{ "title": "ab cd" }"#))

        // When
        let report = try sut.report(of: animated, at: 0.5)
        let rest = try sut.report(of: still, at: 0.5)

        // Then
        let glyphs = report.items.filter { $0.item == .glyphs }
        let fills = glyphs.filter { $0.characters != nil }
        let text = try #require(report.texts.first)
        #expect(report.texts.count == 1)
        #expect(text.transform == glyphs.first?.transform)
        #expect(text.transform == rest.texts.first?.transform)
        #expect(glyphs.count == 1 + 4 * fills.count)
        #expect(fills.map { $0.characters?.map(\.text) ?? [] } == [["a"], ["b", " "], ["c"], ["d"]])
        #expect(fills.flatMap { $0.characters ?? [] } == rest.items.compactMap(\.characters).flatMap { $0 })
        // The word "ab" lies on the items of its two characters, each moved by its own unit's motion.
        let word = try #require(text.words.first)
        let holders = fills.filter { item in
            item.characters?.contains { word.range.contains($0.range.lowerBound) } ?? false
        }
        #expect(word.text == "ab")
        #expect(holders.count == 2)
        #expect(holders.allSatisfy { $0.transform != text.transform })
        #expect(holders[0].transform != holders[1].transform)
    }

    @Test("a title not animated by unit reports every character on its one item, with its text box, lines and words")
    func reportsTitleCharacters() throws {
        // Given
        let document = try resolved(titled(#"{ "title": "ab cd" }"#))

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let item = try #require(report.items.first { $0.item == .glyphs })
        let height = 40.0
        #expect(item.characters == [
            EvaluationCharacter(text: "a", range: 0..<1, rect: Rectangle(x: 0, y: 0, width: 20, height: height), baseline: 32),
            EvaluationCharacter(text: "b", range: 1..<2, rect: Rectangle(x: 20, y: 0, width: 20, height: height), baseline: 32),
            EvaluationCharacter(text: " ", range: 2..<3, rect: Rectangle(x: 40, y: 0, width: 10, height: height), baseline: 32),
            EvaluationCharacter(text: "c", range: 3..<4, rect: Rectangle(x: 50, y: 0, width: 20, height: height), baseline: 32),
            EvaluationCharacter(text: "d", range: 4..<5, rect: Rectangle(x: 70, y: 0, width: 20, height: height), baseline: 32)
        ])
        #expect(report.texts == [
            EvaluationText(
                place: "clips[0]#t",
                id: "t",
                text: "ab cd",
                size: Size(width: 90, height: 40),
                box: Rectangle(x: 0, y: 0, width: 90, height: 40),
                transform: item.transform,
                lines: [EvaluationLine(text: "ab cd", range: 0..<5, baseline: 32, ascent: 32, descent: 8)],
                words: [EvaluationWord(text: "ab", range: 0..<2), EvaluationWord(text: "cd", range: 3..<5)]
            )
        ])
    }

    @Test("a right aligned title reports its characters at the right of its text box, which its item's coordinates are")
    func reportsRightAlignedTitle() throws {
        // Given
        let document = try resolved(titled(#"{ "title": "ab", "width": 200, "paragraph": { "align": "right" } }"#))

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let item = try #require(report.items.first { $0.item == .glyphs })
        #expect(item.characters?.map(\.rect) == [
            Rectangle(x: 160, y: 0, width: 20, height: 40),
            Rectangle(x: 180, y: 0, width: 20, height: 40)
        ])
        #expect(report.texts.first?.size == Size(width: 200, height: 40))
        #expect(report.texts.first?.lines.map(\.baseline) == [32])
    }

    @Test("a character of a base and a combining mark is one character over both scalars, as wide as both glyphs")
    func reportsCombiningMark() throws {
        // Given
        let document = try resolved(titled(#"{ "title": "éx" }"#))

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let item = try #require(report.items.first { $0.item == .glyphs })
        #expect(item.characters == [
            EvaluationCharacter(text: "e\u{301}", range: 0..<2, rect: Rectangle(x: 0, y: 0, width: 40, height: 40), baseline: 32),
            EvaluationCharacter(text: "x", range: 2..<3, rect: Rectangle(x: 40, y: 0, width: 20, height: 40), baseline: 32)
        ])
        #expect(report.texts.first?.words == [EvaluationWord(text: "e\u{301}x", range: 0..<3)])
    }

    @Test("the characters of a ligature share its box, which the character with no glyph of its own takes from the first")
    func reportsLigature() throws {
        // Given
        let document = try resolved(titled(#"{ "title": "fix" }"#))

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let item = try #require(report.items.first { $0.item == .glyphs })
        let ligature = Rectangle(x: 0, y: 0, width: 40, height: 40)
        #expect(item.characters == [
            EvaluationCharacter(text: "f", range: 0..<1, rect: ligature, baseline: 32),
            EvaluationCharacter(text: "i", range: 1..<2, rect: ligature, baseline: 32),
            EvaluationCharacter(text: "x", range: 2..<3, rect: Rectangle(x: 40, y: 0, width: 20, height: 40), baseline: 32)
        ])
    }

    @Test("spaces hanging past a line's end are no characters and no part of the line's range, and a line with no character has an empty one")
    func leavesHangingSpacesOut() throws {
        // Given
        let document = try resolved(titled(#"{ "title": "ab  \n\ncd" }"#))

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let item = try #require(report.items.first { $0.item == .glyphs })
        let lines = try #require(report.texts.first?.lines)
        let step = lines[1].baseline - lines[0].baseline
        #expect(item.characters?.map(\.text) == ["a", "b", "c", "d"])
        #expect(item.characters?.map(\.range) == [0..<1, 1..<2, 6..<7, 7..<8])
        #expect(lines.map(\.text) == ["ab", "", "cd"])
        #expect(lines.map(\.range) == [0..<2, 5..<5, 6..<8])
        #expect(step > 0)
        #expect(lines[2].baseline - lines[1].baseline == step)
        #expect(item.characters?.map(\.baseline) == [32, 32, lines[2].baseline, lines[2].baseline])
    }

    @Test("a title by unit with no character reports an empty list on its one item, and its one line with no character")
    func reportsTitleWithoutCharacter() throws {
        // Given
        let document = try resolved(titled(#"{ "title": "  ", "animation": { "preset": "frames/fade", "by": "word" } }"#))

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let glyphs = report.items.filter { $0.item == .glyphs }
        let text = try #require(report.texts.first)
        #expect(glyphs.map(\.characters) == [[]])
        #expect(text.text == "  ")
        #expect(text.lines.map(\.range) == [0..<0])
        #expect(text.lines.map(\.text) == [""])
        #expect(text.words == [])
    }

    @Test("a character with no glyph is reported with its group's first character, or where its line starts when none comes before it")
    func reportsCharactersWithoutGlyphs() throws {
        // Given
        let shaper = ShaperTable(ignored: ["\u{200B}", "\u{2060}"])
        let document = try resolved(titled(#"{ "title": "\u200Bab\n\u2060" }"#), shaper: shaper)

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let item = try #require(report.items.first { $0.item == .glyphs })
        let second = try #require(report.texts.first?.lines.last?.baseline)
        let group = Rectangle(x: 0, y: 0, width: 20, height: 40)
        #expect(item.characters == [
            EvaluationCharacter(text: "\u{200B}", range: 0..<1, rect: group, baseline: 32),
            EvaluationCharacter(text: "a", range: 1..<2, rect: group, baseline: 32),
            EvaluationCharacter(text: "b", range: 2..<3, rect: Rectangle(x: 20, y: 0, width: 20, height: 40), baseline: 32),
            EvaluationCharacter(
                text: "\u{2060}",
                range: 4..<5,
                rect: Rectangle(x: 0, y: second - 32, width: 0, height: 40),
                baseline: second
            )
        ])
    }

    @Test("a unit of a character alone on a line with no glyph reports it where the line starts, which its extent is")
    func reportsUnitWithoutGlyphs() throws {
        // Given
        let shaper = ShaperTable(ignored: ["\u{200B}", "\u{2060}"])
        let document = try resolved(
            titled(#"{ "title": "\u200Bab\n\u2060", "animation": { "preset": "frames/fade", "by": "word" } }"#),
            shaper: shaper
        )

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let fills = report.items.filter { $0.characters != nil }
        let joiner = try #require(fills.last?.characters?.first)
        #expect(fills.map { $0.characters?.map(\.text) } == [["\u{200B}", "a", "b"], ["\u{2060}"]])
        #expect(joiner.rect.width == 0)
        #expect(joiner.rect.x == 0)
        #expect(fills.last?.rect == joiner.rect)
    }

    @Test("a title's box is its text box grown by its background's padding, in its text box, and its characters stay put")
    func reportsPaddedBox() throws {
        // Given
        let document = try resolved(titled(#"""
            { "title": "ab", "paragraph": { "background": { "color": "#FF0000", "padding": [8, 12] } } }
            """#))

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        let item = try #require(report.items.first { $0.item == .glyphs })
        #expect(report.texts.first?.box == Rectangle(x: -12, y: -8, width: 64, height: 56))
        #expect(report.texts.first?.size == Size(width: 40, height: 40))
        #expect(item.rect == Rectangle(x: 0, y: 0, width: 40, height: 40))
        #expect(item.characters?.first?.rect == Rectangle(x: 0, y: 0, width: 20, height: 40))
    }

    @Test("a title in a compound clip is reported in its continued place, sampled at the time its sequence shows")
    func reportsNestedTitle() throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 4,
                               "connected": [ { "media": { "kind": "sequence", "format": { "size": [1080, 1920] },
                                                           "theme": { "styles": { "caption": { "size": 40, "color": "#000000" } } },
                                                           "storyline": [ { "solid": "#000000", "duration": 2 } ],
                                                           "clips": [ { "id": "n", "title": "ab", "style": "caption", "position": [400, 225], "at": [1, 2] } ] },
                                                "at": [1, 3] } ] } ] }
            """#)

        // When
        let early = try sut.report(of: document, at: 1.5)
        let late = try sut.report(of: document, at: 2.5)

        // Then
        #expect(early.texts == [])
        #expect(late.texts.map(\.place) == ["storyline[0].connected[0].media.clips[0]#n"])
        #expect(late.items.first { $0.item == .glyphs }?.characters?.map(\.text) == ["a", "b"])
    }

    @Test("a title drawn at no time of its window, and one used as a track matte, have no text entry")
    func leavesUndrawnTitlesOut() throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "color": "#000000" } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [
                { "id": "late", "title": "ab", "style": "caption", "position": [400, 225], "at": [2, 3] },
                { "id": "m", "title": "cd", "style": "caption", "position": [400, 225], "at": [0, 3] },
                { "id": "a", "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 50, 50], "at": [0, 3],
                  "trackMatte": { "clip": "m", "mode": "alpha" } } ] }
            """#)

        // When
        let report = try sut.report(of: document, at: 1)

        // Then
        #expect(report.texts == [])
        #expect(report.items.allSatisfy { $0.characters == nil })
    }

    @Test("a glyphs item's characters and a title's text are written as FRAMES-23 gives them, each range in whole scalars")
    func writesTextMachineOutput() throws {
        // Given
        let document = try resolved(titled(#"""
            { "title": "ab", "paragraph": { "background": { "color": "#FF0000", "padding": [8, 12] } } }
            """#))
        let output = try sut.report(of: document, at: 1).machineOutput.objectValue

        // When
        let glyphs = try #require(output?["items"]?.arrayValue?.last)
        let texts = try #require(output?["texts"])
        let text = JSONWriter().write(.array([glyphs, texts]))

        // Then
        #expect(text == #"""
            [
              {
                "place": "clips[0]#t",
                "id": "t",
                "kind": "title",
                "item": "glyphs",
                "bounds": [368, 197, 64, 56],
                "opacity": 1,
                "transform": [1, 0, 0, 1, 380, 205],
                "rect": [0, 0, 40, 40],
                "characters": [
                  {
                    "text": "a",
                    "range": [0, 1],
                    "rect": [0, 0, 20, 40],
                    "baseline": 32
                  },
                  {
                    "text": "b",
                    "range": [1, 2],
                    "rect": [20, 0, 20, 40],
                    "baseline": 32
                  }
                ]
              },
              [
                {
                  "place": "clips[0]#t",
                  "id": "t",
                  "text": "ab",
                  "size": [40, 40],
                  "box": [-12, -8, 64, 56],
                  "transform": [1, 0, 0, 1, 380, 205],
                  "lines": [
                    {
                      "text": "ab",
                      "range": [0, 2],
                      "baseline": 32,
                      "ascent": 32,
                      "descent": 8
                    }
                  ],
                  "words": [
                    {
                      "text": "ab",
                      "range": [0, 2]
                    }
                  ]
                }
              ]
            ]

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

    // A picture of the first frame of a file evaluation opens nothing of.
    private var frame: MediaFrame {
        MediaFrame(media: PinnedMedia(source: .file(PinnedFile(path: "/abs/page.png", sha256: ""))), index: 0)
    }

    // A run of one glyph at the pen (10, 30) of the item's own coordinates.
    private func run(
        stroke: TextStroke?,
        highlight: DrawnHighlight?
    ) -> DrawnGlyphRun {
        DrawnGlyphRun(
            font: PinnedFile(path: "/abs/font.ttf", sha256: ""),
            face: "Regular",
            size: 24,
            color: black,
            stroke: stroke,
            highlight: highlight,
            underline: nil,
            glyphs: [PositionedGlyph(id: 1, x: 10, y: 30)]
        )
    }

    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func resolved(
        _ document: String,
        animations: [String: AnimationPreset]
    ) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: PresetTable(transitions: [:], animations: animations, filters: [:]),
            ocr: Fixture.ocr,
            languages: nil,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func resolved(
        _ document: String,
        shaper: ShaperTable
    ) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Fixture.presets,
            ocr: Fixture.ocr,
            languages: nil,
            tracker: Fixture.tracker,
            shaper: shaper,
            library: Fixture.library
        )

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    // A document of one title `t` in the caption style, 40 pixels, over a screen recording, drawn from 0 to 2, its
    // other fields `clip`'s.
    private func titled(_ clip: String) -> String {
        let fields = clip.drop { $0 != "{" }.dropFirst()

        return #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "color": "#000000" } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "id": "t", "style": "caption", "position": [400, 225], "at": [0, 2], \#(fields) ] }
            """#
    }

    private func isClose(
        _ transform: AffineTransform,
        _ other: AffineTransform
    ) -> Bool {
        [transform.a - other.a, transform.b - other.b, transform.c - other.c, transform.d - other.d,
         transform.tx - other.tx, transform.ty - other.ty]
            .allSatisfy { abs($0) < 1e-9 }
    }

    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        [rectangle.x - other.x, rectangle.y - other.y, rectangle.width - other.width, rectangle.height - other.height]
            .allSatisfy { abs($0) < 1e-9 }
    }
}
