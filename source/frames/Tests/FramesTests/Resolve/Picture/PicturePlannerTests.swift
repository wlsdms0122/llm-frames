//
//  PicturePlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("PicturePlanner Tests")
struct PicturePlannerTests {
    // MARK: - Property
    private let sut = Fixture.documentPlanner

    // `/abs/page.png` is 1000x800, and the base theme's `baseWidth` is 1206.
    private let baseWidth = 1206.0

    // MARK: - Initializer

    // MARK: - Test
    @Test("canvas operations crop, scale and pad the source, which keeps its crop in its own pixels")
    func runsCanvasOperations() throws {
        // Given
        let document = #"""
            { "kind": "image", "source": "/abs/page.png",
              "ops": [ { "crop": [100, 100, 400, 200] }, { "resize": { "width": 800 } }, { "pad": 20 }, { "border": true } ] }
            """#

        // When
        let plan = try picture(document)

        // Then
        let frame = Rectangle(x: 20, y: 20, width: 800, height: 400)
        #expect(plan.size == Size(width: 840, height: 440))
        #expect(plan.steps.first == DrawingStep(
            origin: DrawingOrigin(place: Place.root.appending(key: "source"), id: nil, kind: .image),
            content: .picture(
                .media(try mediaFile("/abs/page.png"), name: "/abs/page.png", time: 0),
                crop: Rectangle(x: 100, y: 100, width: 400, height: 200),
                frame: frame
            ),
            clip: frame
        ))
        let fills = plan.steps.compactMap { step -> Rectangle? in
            guard case let .fill(rectangle, color) = step.content, color == Color(written: "#FFFFFF") else { return nil }

            return rectangle
        }
        #expect(fills.count == 4)
        let room: Double = fills.map { $0.width * $0.height }.reduce(0, +)
        #expect(room == 840 * 440 - 800 * 400)
        #expect(plan.steps.last?.content == .border(
            Rectangle(x: 0, y: 0, width: 840, height: 440),
            width: 3 * (840 / baseWidth),
            color: Color(written: "#D9D9D9")
        ))
    }

    @Test(
        "an area is written in the source's media pixels and a drawing's lengths scale with the canvas it is drawn on",
        arguments: [
            #"[ { "crop": [100, 100, 400, 200] }, { "shape": "box", "area": [150, 150, 100, 50] }, { "resize": { "scale": 2 } } ]"#,
            #"[ { "crop": [100, 100, 400, 200] }, { "resize": { "scale": 2 } }, { "shape": "box", "area": [150, 150, 100, 50] } ]"#
        ]
    )
    func mapsAreasThroughCanvasOperations(operations: String) throws {
        // Given
        let document = #"{ "kind": "image", "source": "/abs/page.png", "ops": \#(operations) }"#

        // When
        let plan = try picture(document)

        // Then
        let box = try #require(plan.steps.first { if case .box = $0.content { true } else { false } })
        guard case let .box(rectangle, width, radius, _) = box.content else { return }
        #expect(rectangle == Rectangle(x: 100, y: 100, width: 200, height: 100))
        #expect(abs(width - 8 * 800 / baseWidth) < 1e-9)
        #expect(abs(radius - 18 * 800 / baseWidth) < 1e-9)
        #expect(box.clip == Rectangle(x: 0, y: 0, width: 800, height: 400))
    }

    @Test(
        "a resize makes the canvas its whole-pixel target size, and the picture fills it exactly",
        arguments: [
            (#"{ "kind": "image", "source": "/abs/page.png", "ops": [ { "resize": { "width": 333 } } ] }"#, Size(width: 333, height: 266)),
            (#"{ "kind": "image", "source": "/abs/strip.png", "ops": [ { "resize": { "scale": 0.2 } } ] }"#, Size(width: 200, height: 1))
        ]
    )
    func resizesToTargetSize(
        document: String,
        size: Size
    ) throws {
        // When
        let plan = try picture(document)

        // Then
        let bounds = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        #expect(plan.size == size)
        guard case let .picture(_, _, frame) = plan.steps[0].content else {
            Issue.record("the picture is not drawn first")
            return
        }
        #expect(isClose(frame, bounds))
        #expect(isClose(plan.steps[0].clip, bounds))
    }

    @Test("a later crop clips what was drawn, and a later pad never reveals it")
    func clipsEarlierDrawings() throws {
        // Given
        let document = #"""
            { "kind": "image", "source": "/abs/page.png",
              "ops": [ { "shape": "fill", "area": [0, 0, 500, 500] }, { "crop": [100, 100, 200, 200] }, { "pad": 10 } ] }
            """#

        // When
        let plan = try picture(document)

        // Then
        #expect(plan.steps[1].content == .fill(Rectangle(x: -90, y: -90, width: 500, height: 500), color: Color(written: "#FFD43B80")))
        #expect(plan.steps[1].clip == Rectangle(x: 10, y: 10, width: 200, height: 200))
    }

    @Test(
        "coordinates outside the source reach into a pad only after it, and a drawing wholly outside its canvas stops",
        arguments: [
            (#"[ { "pad": 20 }, { "shape": "fill", "area": [-20, -20, 10, 10] } ]"#, nil),
            (
                #"[ { "shape": "fill", "area": [-20, -20, 10, 10] }, { "pad": 20 } ]"#,
                "ops[0].area (fill): lies wholly outside the canvas of 1000x800 at its operation"
            ),
            (
                #"[ { "crop": [0, 0, 100, 100] }, { "title": "Hi", "style": "label", "position": [500, 500] } ]"#,
                "ops[1].position (title): lies wholly outside the canvas of 100x100 at its operation"
            )
        ] as [(String, String?)]
    )
    func reachesIntoPads(
        operations: String,
        message: String?
    ) throws {
        // Given
        let document = #"{ "kind": "image", "source": "/abs/page.png", "ops": \#(operations) }"#

        // When, Then
        guard let message else {
            let plan = try picture(document)
            #expect(plan.steps.last?.content == .fill(Rectangle(x: 0, y: 0, width: 10, height: 10), color: Color(written: "#FFD43B80")))
            return
        }
        let error = #expect(throws: ResolveError.self) { try picture(document) }
        #expect(error?.description == message)
    }

    @Test(
        "a title or banner line naming a style the theme does not hold stops at its style, listing the theme's styles",
        arguments: [
            (#"{ "title": "Hi", "style": "nope", "position": [400, 225] }"#, "ops[0].style (title)"),
            (#"{ "banner": [ "Head", { "text": "Line", "style": "nope" } ], "edge": "top" }"#, "ops[0].banner[1].style (banner)")
        ]
    )
    func refusesUnknownStyle(
        operation: String,
        place: String
    ) throws {
        // Given
        let document = #"{ "kind": "image", "source": "/abs/page.png", "ops": [ \#(operation) ] }"#

        // When, Then
        let error = #expect(throws: ThemeError.self) { try picture(document) }
        #expect(error?.description == place + #": style "nope" is not in styles, "#
            + #"which hold "banner", "bannerHead", "heading", "headline", "label", "subtitle""#)
    }

    @Test("a text area is found on the source picture at the document's time, grown by padding in its pixels")
    func findsTextAreas() throws {
        // Given
        let document = ##"""
            { "kind": "image", "source": "/abs/short.mp4", "time": 1,
              "ops": [ { "shape": "dim", "area": "Send", "color": "#00000080" } ] }
            """##

        // When
        let plan = try picture(document)

        // Then
        let padding = 14 * (1080 / baseWidth)
        #expect(plan.steps[0].content == .picture(
            .media(try mediaFile("/abs/short.mp4"), name: "/abs/short.mp4", time: 1),
            crop: Rectangle(x: 0, y: 0, width: 1080, height: 1920),
            frame: Rectangle(x: 0, y: 0, width: 1080, height: 1920)
        ))
        guard case let .dim(area, color) = plan.steps[1].content else {
            Issue.record("the dim is not drawn")
            return
        }
        #expect(isClose(area, Fixture.send.grown(by: padding)))
        #expect(color == Color(written: "#00000080"))
    }

    @Test("a label goes on the first theme side where it fits on the canvas, and stops when it fits on none")
    func placesLabels() throws {
        // Given
        let fits = #"{ "kind": "image", "source": "/abs/page.png", "ops": [ { "shape": "box", "area": [100, 100, 100, 100], "label": "Here" } ] }"#
        let tight = #"{ "kind": "image", "source": "/abs/page.png", "ops": [ { "crop": [0, 0, 120, 120] }, { "shape": "box", "area": [2, 2, 116, 116], "label": "A label longer than the canvas" } ] }"#

        // When
        let plan = try picture(fits)

        // Then
        guard case let .text(_, frame) = plan.steps.last?.content else {
            Issue.record("the label is not drawn last")
            return
        }
        #expect(frame.x == 200)
        #expect(frame.center.y == 150)
        let error = #expect(throws: ResolveError.self) { try picture(tight) }
        #expect(error?.description == #"ops[1].label (box): the label "A label longer than the canvas" fits inside the canvas on none of the sides right, bottom, left, top"#)
    }

    @Test("a title's anchor point sits at its position, and an adjustment covers its area or the canvas")
    func placesTitlesAndAdjustments() throws {
        // Given
        let document = #"""
            { "kind": "image", "source": "/abs/page.png",
              "ops": [ { "title": "Hi", "style": "label", "position": [500, 400] }, { "adjust": "frames/warm" }, { "adjust": ["frames/warm", "none"], "area": [0, 0, 10, 10] } ] }
            """#
        let unknown = #"{ "kind": "image", "source": "/abs/page.png", "ops": [ { "adjust": "mine/cold" } ] }"#

        // When
        let plan = try picture(document)

        // Then
        guard case let .text(_, frame) = plan.steps[1].content else {
            Issue.record("the title is not drawn")
            return
        }
        #expect(frame.center == Point(x: 500, y: 400))
        #expect(plan.steps[2].content == .adjustment([], area: Rectangle(x: 0, y: 0, width: 1000, height: 800)))
        #expect(plan.steps[3].content == .adjustment([], area: Rectangle(x: 0, y: 0, width: 10, height: 10)))
        let error = #expect(throws: ResolveError.self) { try picture(unknown) }
        #expect(error?.description == #"ops[0].adjust (adjust): unknown filter preset "mine/cold". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#)
    }

    @Test("a banner extends the canvas by a band as tall as its text, and the picture moves with it")
    func extendsBanners() throws {
        // Given
        let top = #"{ "kind": "image", "source": "/abs/page.png", "ops": [ { "banner": ["Line"], "edge": "top" } ] }"#
        let bottom = #"{ "kind": "image", "source": "/abs/page.png", "ops": [ { "banner": ["Line"], "edge": "bottom" } ] }"#

        // When
        let above = try picture(top)
        let below = try picture(bottom)

        // Then
        let height = above.size.height - 800
        #expect(height > 0)
        #expect(below.size == above.size)
        guard case let .picture(_, _, frame) = above.steps[0].content, case let .text(_, line) = above.steps.last?.content else {
            Issue.record("the banner is not drawn")
            return
        }
        #expect(frame.y == height)
        #expect(line.maxY < height)
        guard case let .text(_, lowLine) = below.steps.last?.content else { return }
        #expect(lowLine.y > 800)
    }

    @Test("a layout puts items on one row by default, each centred in its cell, with a border around every cell")
    func plansLayout() throws {
        // Given
        let document = #"""
            { "kind": "layout",
              "items": [ { "image": "/abs/card.png" }, { "image": { "kind": "image", "source": "/abs/page.png" } } ] }
            """#

        // When
        let plan = try picture(document)

        // Then
        let scale = 1080 / baseWidth
        let padding = 40 * scale
        let gap = 40 * scale
        let width: Double = padding * 2 + 1080 + 1000 + gap
        let height: Double = padding * 2 + 1350
        #expect(plan.size == Size(width: width.rounded(.up), height: height.rounded(.up)))
        let pictures = plan.steps.compactMap { step -> Rectangle? in
            guard case let .picture(_, _, frame) = step.content else { return nil }

            return frame
        }
        #expect(pictures.count == 2)
        #expect(isClose(pictures[0], Rectangle(x: padding, y: padding, width: 1080, height: 1350)))
        #expect(isClose(pictures[1], Rectangle(x: padding + 1080 + gap, y: padding + 275, width: 1000, height: 800)))
        let borders = plan.steps.filter { if case .border = $0.content { true } else { false } }
        #expect(borders.count == 2)
    }

    @Test("a heading sits above its cell, and columns wrap the items into rows")
    func plansLayoutRows() throws {
        // Given
        let document = #"""
            { "kind": "layout", "columns": 1, "border": false,
              "items": [ { "heading": "Before", "image": "/abs/page.png" }, { "image": "/abs/card.png" } ] }
            """#

        // When
        let plan = try picture(document)

        // Then
        let pictures = plan.steps.compactMap { step -> Rectangle? in
            guard case let .picture(_, _, frame) = step.content else { return nil }

            return frame
        }
        guard case let .text(heading, frame) = plan.steps[1].content else {
            Issue.record("the heading is not drawn")
            return
        }
        #expect(abs(frame.maxY - pictures[0].y) < 1e-9)
        #expect(pictures[0].x == pictures[1].x + 40)
        let gap: Double = 40 * 1080 / baseWidth
        #expect(abs(pictures[1].y - (pictures[0].maxY + gap)) < 1e-9)
        #expect(heading.lineCount == 1)
        #expect(!plan.steps.contains { if case .border = $0.content { true } else { false } })
    }

    @Test(
        "a layout of no items or no columns stops, and so does sound where a picture is taken",
        arguments: [
            (#"{ "kind": "layout", "items": [] }"#, "items (layout): a layout needs at least one item"),
            (#"{ "kind": "layout", "columns": 0, "items": [ { "image": "/abs/card.png" } ] }"#, "columns (layout): columns must be 1 or more, found 0"),
            (#"{ "kind": "image", "source": "/abs/bgm.m4a" }"#, #"source (image): media "/abs/bgm.m4a" is sound, and a picture is taken here"#)
        ]
    )
    func refusesPictures(
        document: String,
        message: String
    ) throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) { try picture(document) }
        #expect(error?.description == message)
    }

    @Test("an image document stands in for a path on a storyline, its resolved size the picture's size")
    func standsInForPath() throws {
        // Given
        let document = #"""
            { "kind": "sequence",
              "storyline": [ { "media": { "kind": "image", "source": "/abs/page.png", "ops": [ { "pad": 20 } ] }, "duration": 1 } ] }
            """#

        // When
        let plan = try #require(try sut.plan(Fixture.json(document)).sequence)

        // Then
        #expect(plan.format.size == Size(width: 1040, height: 840))
        #expect(plan.storyline[0].nested?.size == Size(width: 1040, height: 840))
    }

    @Test("a connected clip and a layout item that are image documents are drawn from their own plans, in their places")
    func plansNestedImageDocuments() throws {
        // Given
        let image = #"{ "kind": "image", "source": "/abs/page.png", "ops": [ { "pad": 20 } ] }"#
        let sequence = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "media": \#(image), "at": [0, 1] } ] } ] }
            """#
        let layout = #"{ "kind": "layout", "items": [ { "image": \#(image) } ] }"#

        // When
        let sequencePlan = try #require(try sut.plan(Fixture.json(sequence)).sequence)
        let layoutPlan = try picture(layout)

        // Then
        let alone = try picture(image)
        let drawn = layoutPlan.steps.compactMap { step -> (DrawnPicture, Rectangle)? in
            guard case let .picture(picture, _, frame) = step.content else { return nil }

            return (picture, frame)
        }
        guard
            case let .picture(connected) = sequencePlan.clips[0].nested,
            case let .picture(item)? = drawn.first?.0
        else {
            Issue.record("the image documents are not drawn from their own plans")
            return
        }
        #expect(drawn.count == 1)
        #expect(connected.steps.map(\.content) == alone.steps.map(\.content))
        #expect(item.steps.map(\.content) == alone.steps.map(\.content))
        #expect(drawn.first?.1.width == 1040)
        #expect(drawn.first?.1.height == 840)
        #expect(Set(connected.steps.map(\.origin.place.description)) == [
            "storyline[0].connected[0].media.source",
            "storyline[0].connected[0].media.ops[0]"
        ])
        #expect(Set(item.steps.map(\.origin.place.description)) == ["items[0].image.source", "items[0].image.ops[0]"])
    }

    @Test("every step is drawn by its operation, a shape's label too, and the source picture by the source")
    func namesImageSteps() throws {
        // Given
        let document = #"""
            { "kind": "image", "source": "/abs/page.png",
              "ops": [ { "crop": [100, 100, 400, 200] }, { "pad": 20, "id": "room" },
                       { "shape": "box", "area": [150, 150, 100, 50], "label": "here" },
                       { "banner": [ "Line" ], "edge": "bottom" }, { "border": true } ] }
            """#

        // When
        let plan = try picture(document)

        // Then
        let origins = plan.steps.map { step in
            "\(step.origin.place) \(step.origin.id ?? "-") \(step.origin.kind.label)"
        }
        #expect(origins.first == "source - image")
        #expect(origins.filter { $0 == "ops[1]#room room pad" }.count == 4)
        #expect(origins.filter { $0 == "ops[2] - box" }.count == 2)
        #expect(origins.filter { $0 == "ops[3] - banner" }.count == 2)
        #expect(origins.last == "ops[4] - border")
        #expect(!origins.contains { $0.hasPrefix("ops[0]") })
    }

    @Test("a layout's background and banner are its own, and a cell's heading, picture and border its item's")
    func namesLayoutSteps() throws {
        // Given
        let document = #"""
            { "kind": "layout", "banner": [ "Line" ],
              "items": [ { "heading": "Before", "image": "/abs/page.png" }, { "image": "/abs/card.png" } ] }
            """#

        // When
        let plan = try picture(document)

        // Then
        let origins = plan.steps.map { step in "\(step.origin.place) \(step.origin.kind.label)" }
        #expect(origins == [
            "top level layout",
            "banner layout",
            "items[0] layout item",
            "items[0] layout item",
            "items[0] layout item",
            "items[1] layout item",
            "items[1] layout item"
        ])
    }

    // MARK: - Private
    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        [
            rectangle.x - other.x,
            rectangle.y - other.y,
            rectangle.width - other.width,
            rectangle.height - other.height
        ].allSatisfy { abs($0) < 1e-9 }
    }

    private func picture(_ document: String) throws -> PicturePlan {
        guard case let .picture(plan) = try sut.plan(Fixture.json(document)) else {
            Issue.record("the document does not plan as a picture")
            return PicturePlan(kind: "image", size: Size(width: 0, height: 0), steps: [])
        }

        return plan
    }

    private func mediaFile(_ file: String) throws -> MediaFile {
        let media = try MediaResolver(mediaFacts: Fixture.mediaFacts, presets: Fixture.presets, library: Fixture.library)
            .media(of: .file(file), place: .root, kind: .image, theme: .base)
        guard case let .file(mediaFile) = media.source else {
            Issue.record("the media is not a file")
            return MediaFile(path: file)
        }

        return mediaFile
    }
}
