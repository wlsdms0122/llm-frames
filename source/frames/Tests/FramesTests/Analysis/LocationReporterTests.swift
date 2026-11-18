//
//  LocationReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("LocationReporter Tests")
struct LocationReporterTests {
    // MARK: - Property
    private let sut = LocationReporter()

    private let size = Size(width: 200, height: 100)
    private let transparent = Color(written: "#00000000")
    private let red = Color(written: "#FF0000")
    // Frames every half second, the third at 1.
    private let video = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/run.mp4", sha256: String(repeating: "a", count: 64))),
        frameTimes: [0, 0.5, 1, 1.5]
    )
    private let clip = ItemOrigin(place: "clips[1]#shot", id: "shot", kind: "video")
    private let rect = ItemOrigin(place: "clips[0]", id: nil, kind: "rect")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sequence stops on a time outside [0, duration) as still does", arguments: [-0.5, 4])
    func stopsOnTimeOutsideSequence(time: Double) throws {
        // Given
        let document = try resolved(#"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "storyline": [ { "solid": "#FF8000", "duration": 4 } ] }
            """#)

        // When, Then
        #expect(throws: ExportError.timeOutside(option: "--at", time: time, end: 4, kind: "sequence")) {
            try sut.report(of: document, at: time, point: Point(x: 10, y: 10))
        }
    }

    @Test("a point on a turned, scaled picture maps back through its transform and source rect into its media's pixels")
    func mapsPointThroughTransform() throws {
        // Given
        // The 40 x 20 box shows the 400 x 200 picture, so one box pixel is ten media pixels. Doubled and turned a
        // quarter clockwise about the box's centre, it stands at (60, 10) to (100, 90), its x axis pointing down.
        let picture = PictureItem(
            source: .media(MediaFrame(media: video, index: 2)),
            rectangle: Rectangle(x: 0, y: 0, width: 400, height: 200),
            destination: Rectangle(x: 0, y: 0, width: 40, height: 20)
        )
        let transform = AffineTransform(scale: 2, about: Point(x: 20, y: 10))
            .concatenating(AffineTransform(rotation: 90, about: Point(x: 20, y: 10)))
            .concatenating(AffineTransform(translation: Point(x: 60, y: 40)))
        let item = DisplayItem(transform: transform, content: .picture(picture), origin: clip)

        // When
        let report = sut.report(of: list([item]), point: Point(x: 95, y: 20))

        // Then
        // (95, 20) is 5 in from the right and 10 down from the top: box (5, 2.5), media (50, 25).
        let hit = try #require(report.hits.first)
        let point = try #require(hit.media?.point)
        #expect(report.hits.count == 1)
        #expect(hit.origin == clip)
        #expect(hit.media?.file == "/abs/run.mp4")
        #expect(hit.media?.mediaTime == 1)
        #expect(abs(point.x - 50) < 1e-9 && abs(point.y - 25) < 1e-9)
    }

    @Test("a point in a nested list maps through the list's picture and the item inside it, named by its own clip")
    func mapsPointThroughNestedList() throws {
        // Given
        // A nested list of 100 x 50 drawn at (100, 50) scaled 1, holding the media's middle 200 x 100 over all of it.
        let media = DisplayItem(
            content: .picture(PictureItem(
                source: .media(MediaFrame(media: video, index: 0)),
                rectangle: Rectangle(x: 100, y: 50, width: 200, height: 100),
                destination: Rectangle(x: 0, y: 0, width: 100, height: 50)
            )),
            origin: ItemOrigin(place: "storyline[0].media.storyline[1]", id: nil, kind: "video")
        )
        let nested = DisplayList(size: Size(width: 100, height: 50), background: transparent, seed: 0, items: [media])
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: Rectangle(x: 0, y: 0, width: 100, height: 50),
            destination: Rectangle(x: 100, y: 50, width: 100, height: 50)
        )
        let item = DisplayItem(
            content: .picture(picture),
            origin: ItemOrigin(place: "storyline[0]", id: nil, kind: "compound")
        )

        // When
        let report = sut.report(of: list([item]), point: Point(x: 150, y: 75))

        // Then
        // The nested list's centre (50, 25) shows the media's centre (200, 100).
        let hit = try #require(report.hits.first)
        #expect(hit.origin?.place == "storyline[0].media.storyline[1]")
        #expect(hit.media?.point == Point(x: 200, y: 100))
        #expect(hit.media?.mediaTime == 0)
    }

    @Test("hits come topmost first, and a point beside a fill, in a stroked rect's middle or outside a mask is not under it")
    func listsHitsTopmostFirst() {
        // Given
        let frame = Rectangle(x: 0, y: 0, width: 200, height: 100)
        let outside = DisplayItem(content: .path(PathItem(
            filling: Rectangle(x: 0, y: 0, width: 50, height: 100),
            color: red
        )))
        let picture = DisplayItem(
            content: .picture(PictureItem(
                source: .media(MediaFrame(media: video, index: 1)),
                rectangle: Rectangle(x: 0, y: 0, width: 200, height: 100),
                destination: frame
            )),
            origin: clip
        )
        let stroke = DisplayItem(
            content: .path(PathItem(
                geometry: .rect(Rectangle(x: 80, y: 20, width: 40, height: 40), radius: 0),
                fill: nil,
                stroke: PathStroke(width: 4, color: red, join: .miter, cap: .butt, start: .none, end: .none)
            )),
            origin: rect
        )
        let masked = DisplayItem(
            mask: Rectangle(x: 0, y: 0, width: 10, height: 10),
            content: .path(PathItem(filling: frame, color: red))
        )

        // When
        let onEdge = sut.report(of: list([outside, picture, stroke, masked]), point: Point(x: 81, y: 40))
        let inMiddle = sut.report(of: list([outside, picture, stroke, masked]), point: Point(x: 100, y: 40))
        let inMargin = sut.report(of: list([outside, picture, stroke, masked]), point: Point(x: 20, y: 40))

        // Then
        #expect(onEdge.hits.map(\.origin) == [rect, clip])
        #expect(inMiddle.hits.map(\.origin) == [clip])
        #expect(inMargin.hits.map(\.origin) == [clip, nil])
    }

    @Test("a picture that shows its whole media, as a cover does, reports its frame but no point in it")
    func leavesWholePicturePointOut() throws {
        // Given
        let cover = DisplayItem(content: .picture(PictureItem(
            source: .media(MediaFrame(media: video, index: 3)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 200, height: 100)
        )))

        // When
        let report = sut.report(of: list([cover]), point: Point(x: 10, y: 10))

        // Then
        #expect(report.hits == [
            LocationHit(origin: nil, media: LocatedMedia(file: "/abs/run.mp4", mediaTime: 1.5, point: nil))
        ])
    }

    @Test("a path with an arrowhead is under the point on its line and its head, but not beside the head's tip")
    func hitsArrowShape() {
        // Given
        let arrow = DisplayItem(
            content: .path(PathItem(
                geometry: .polyline([Point(x: 10, y: 50), Point(x: 110, y: 50)], isClosed: false),
                fill: nil,
                stroke: PathStroke(width: 4, color: red, join: .round, cap: .butt, start: .none, end: .arrow)
            )),
            origin: ItemOrigin(place: "clips[2]", id: nil, kind: "shape")
        )

        // When
        let hits = [Point(x: 50, y: 51), Point(x: 95, y: 56), Point(x: 108, y: 58)].map { point in
            sut.report(of: list([arrow]), point: point).hits.count
        }

        // Then
        #expect(hits == [1, 1, 0])
    }

    @Test("a trimmed path's arrowhead sits at the end of its drawn stroke, and nothing past it is under the point")
    func hitsTrimmedArrowShape() {
        // Given
        // Half of the line is drawn, to x = 60, its head from its base at x = 44 to its tip there.
        let arrow = DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 10, y: 50), Point(x: 110, y: 50)], isClosed: false),
            fill: nil,
            stroke: PathStroke(width: 4, color: red, join: .round, cap: .butt, start: .none, end: .arrow),
            trim: Trim(start: 0, end: 0.5)
        )))

        // When
        let hits = [Point(x: 30, y: 51), Point(x: 50, y: 54), Point(x: 90, y: 50)].map { point in
            sut.report(of: list([arrow]), point: point).hits.count
        }

        // Then
        #expect(hits == [1, 1, 0])
    }

    @Test("a resolved document is located at the time, its storyline media mapped back into the frame it draws")
    func locatesResolvedSequence() throws {
        // Given
        let document = try ResolvedSequence(
            plan: Fixture.documentPlanner.plan(Fixture.json(#"""
                { "kind": "sequence", "format": { "size": [540, 960] },
                  "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 4 } ] }
                """#)),
            hashes: FileHashTable()
        )

        // When
        let report = try sut.report(of: document, at: 2.5, point: Point(x: 270, y: 480))

        // Then
        // The 1080 x 1920 picture fills the 540 x 960 frame, so its centre is the picture's, on the frame at 2. The
        // background lies below it.
        let entry = ItemOrigin(place: "storyline[0]", id: nil, kind: "video")
        let hit = try #require(report.hits.first)
        #expect(report.hits.map(\.origin) == [entry, nil])
        #expect(hit.media?.point == Point(x: 540, y: 960))
        #expect(hit.media?.mediaTime == 2)
    }

    @Test("the machine output is the locate object FRAMES-23 gives, with media only on a picture of media")
    func writesMachineOutput() {
        // Given
        let report = LocationReport(hits: [
            LocationHit(origin: rect, media: nil),
            LocationHit(
                origin: clip,
                media: LocatedMedia(file: "/abs/run.mp4", mediaTime: 0.5, point: Point(x: 0.1 + 0.2, y: 4))
            ),
            LocationHit(origin: nil, media: nil)
        ])

        // When
        let text = JSONWriter().write(report.machineOutput)

        // Then
        #expect(text == #"""
            {
              "locate": "1.0.0",
              "hits": [
                {
                  "place": "clips[0]",
                  "id": null,
                  "kind": "rect"
                },
                {
                  "place": "clips[1]#shot",
                  "id": "shot",
                  "kind": "video",
                  "media": "/abs/run.mp4",
                  "mediaTime": 0.5,
                  "point": [0.3, 4]
                },
                {
                  "place": null,
                  "id": null,
                  "kind": null
                }
              ]
            }

            """#)
    }

    // MARK: - Private
    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func list(_ items: [DisplayItem]) -> DisplayList {
        DisplayList(size: size, background: transparent, seed: 0, items: items)
    }
}
