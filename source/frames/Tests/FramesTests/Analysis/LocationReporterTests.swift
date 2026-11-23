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

    // Masks over a fill of the whole frame, a point, and whether the point is under the masked fill.
    private static let lens = PathGeometry.path(
        [
            PathVertex(vertex: Point(x: 0, y: 50), inTangent: Point(x: 0, y: 40), outTangent: Point(x: 0, y: -40)),
            PathVertex(vertex: Point(x: 100, y: 50), inTangent: Point(x: 0, y: -40), outTangent: Point(x: 0, y: 40))
        ],
        isClosed: true
    )

    // A triangle whose first vertex has a long in tangent, which an open path does not draw.
    private static let triangle = [
        PathVertex(vertex: Point(x: 100, y: 10), inTangent: Point(x: -400, y: 0), outTangent: Point(x: 0, y: 0)),
        PathVertex(vertex: Point(x: 190, y: 10), inTangent: Point(x: 0, y: 0), outTangent: Point(x: 0, y: 0)),
        PathVertex(vertex: Point(x: 140, y: 90), inTangent: Point(x: 0, y: 0), outTangent: Point(x: 0, y: 0))
    ]

    private static let maskCases: [([ItemMask], Point, Bool)] = [
        ([itemMask(.rect(Rectangle(x: 10, y: 10, width: 20, height: 20), radius: 4))], Point(x: 20, y: 20), true),
        ([itemMask(.rect(Rectangle(x: 10, y: 10, width: 20, height: 20), radius: 4))], Point(x: 100, y: 50), false),
        ([itemMask(.ellipse(Rectangle(x: 0, y: 0, width: 10, height: 10)), transform: doubled)], Point(x: 60, y: 10), true),
        ([itemMask(.ellipse(Rectangle(x: 0, y: 0, width: 10, height: 10)), transform: doubled)], Point(x: 40, y: 10), false),
        ([itemMask(.polyline([Point(x: 0, y: 0), Point(x: 100, y: 0), Point(x: 0, y: 100)], isClosed: true))], Point(x: 10, y: 10), true),
        ([itemMask(.polyline([Point(x: 0, y: 0), Point(x: 100, y: 0), Point(x: 0, y: 100)], isClosed: true))], Point(x: 90, y: 90), false),
        // A lens whose curves bulge to y = 20 and 80 lies in the hull of its control points, from y = 10 to 90.
        ([itemMask(lens)], Point(x: 50, y: 50), true),
        ([itemMask(lens)], Point(x: 50, y: 5), false),
        ([itemMask(square), itemMask(.rect(Rectangle(x: 100, y: 10, width: 20, height: 20), radius: 0))], Point(x: 60, y: 20), true),
        ([itemMask(square), itemMask(.rect(Rectangle(x: 100, y: 10, width: 20, height: 20), radius: 0))], Point(x: 60, y: 80), false),
        ([itemMask(square), itemMask(.rect(Rectangle(x: 0, y: 0, width: 5, height: 5), radius: 0), feather: 1)], Point(x: 100, y: 50), true),
        ([itemMask(.rect(left, radius: 0)), itemMask(.rect(right, radius: 0), mode: .intersect)], Point(x: 25, y: 50), false),
        ([itemMask(.rect(left, radius: 0)), itemMask(.rect(right, radius: 0), mode: .intersect)], Point(x: 75, y: 50), true),
        ([itemMask(square, mode: .intersect)], Point(x: 100, y: 50), false),
        ([itemMask(square, isInverted: true)], Point(x: 100, y: 50), true),
        ([itemMask(square, feather: 2)], Point(x: 100, y: 50), true),
        ([itemMask(square, feather: 2, mode: .intersect)], Point(x: 100, y: 50), true),
        ([itemMask(square, isInverted: true, mode: .intersect)], Point(x: 100, y: 50), true),
        ([itemMask(square, mode: .subtract)], Point(x: 20, y: 20), true)
    ]
    private static let square = PathGeometry.rect(Rectangle(x: 10, y: 10, width: 20, height: 20), radius: 0)
    private static let left = Rectangle(x: 0, y: 0, width: 100, height: 100)
    private static let right = Rectangle(x: 50, y: 0, width: 150, height: 100)
    private static let doubled = AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 50, ty: 0)

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
        let report = try sut.report(of: list([item]), point: Point(x: 95, y: 20))

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

    @Test("a point on a picture with a corner pin maps back through the corner pin's homography, and a point of its destination outside the corner pin is under nothing")
    func mapsPointThroughCornerPin() throws {
        // Given
        // The corner pin takes the destination's corners to a trapezoid, and the destination's centre (50, 50) to
        // (97.5, 50), since its homography's w is 0.8 there.
        let media = DisplayItem(
            content: .picture(PictureItem(
                source: .media(MediaFrame(media: video, index: 0)),
                rectangle: Rectangle(x: 0, y: 0, width: 200, height: 200),
                destination: Rectangle(x: 0, y: 0, width: 100, height: 100)
            )),
            origin: clip
        )
        let nested = DisplayList(size: Size(width: 100, height: 100), background: transparent, seed: 0, items: [media])
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: Rectangle(x: 0, y: 0, width: 100, height: 100),
            destination: Rectangle(x: 0, y: 0, width: 100, height: 100),
            cornerPin: Quad(
                topLeft: Point(x: 60, y: 20),
                topRight: Point(x: 160, y: 0),
                bottomRight: Point(x: 160, y: 100),
                bottomLeft: Point(x: 60, y: 80)
            )
        )
        let item = DisplayItem(content: .picture(picture), origin: ItemOrigin(place: "clips[1]#shot", id: "shot", kind: "video"))

        // When
        let centre = try sut.report(of: list([item]), point: Point(x: 97.5, y: 50))
        let outside = try sut.report(of: list([item]), point: Point(x: 30, y: 50))

        // Then
        let hit = try #require(centre.hits.first)
        let point = try #require(hit.media?.point)
        #expect(centre.hits.count == 1)
        #expect(abs(point.x - 100) < 1e-9 && abs(point.y - 100) < 1e-9)
        #expect(outside.hits.isEmpty)
    }

    @Test("a point on a page of a PDF lies in its points, with its page and the media time an image gives")
    func mapsPointOnPage() throws {
        // Given
        // The 100 x 50 box shows the 200 x 100 point page, so one box pixel is two points.
        let page = PinnedMedia(
            source: .page(PinnedFile(path: "/abs/deck.pdf", sha256: String(repeating: "b", count: 64)), page: 3)
        )
        let picture = PictureItem(
            source: .media(MediaFrame(media: page, index: 0)),
            rectangle: Rectangle(x: 0, y: 0, width: 200, height: 100),
            destination: Rectangle(x: 0, y: 0, width: 100, height: 50)
        )
        let item = DisplayItem(transform: .identity, content: .picture(picture), origin: clip)

        // When
        let report = try sut.report(of: list([item]), point: Point(x: 10.25, y: 20))

        // Then
        let hit = try #require(report.hits.first)
        #expect(hit.media == LocatedMedia(file: "/abs/deck.pdf", mediaTime: 0, point: Point(x: 20.5, y: 40), page: 3))
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
        let report = try sut.report(of: list([item]), point: Point(x: 150, y: 75))

        // Then
        // The nested list's centre (50, 25) shows the media's centre (200, 100).
        let hit = try #require(report.hits.first)
        #expect(hit.origin?.place == "storyline[0].media.storyline[1]")
        #expect(hit.media?.point == Point(x: 200, y: 100))
        #expect(hit.media?.mediaTime == 0)
    }

    @Test("hits come topmost first, and a point beside a fill, in a stroked rect's middle or outside a mask is not under it")
    func listsHitsTopmostFirst() throws {
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
                stroke: PathStroke(width: 4, paint: .color(red), join: .miter, cap: .butt, start: .none, end: .none)
            )),
            origin: rect
        )
        let masked = DisplayItem(
            mask: mask(Rectangle(x: 0, y: 0, width: 10, height: 10)),
            content: .path(PathItem(filling: frame, color: red))
        )

        // When
        let onEdge = try sut.report(of: list([outside, picture, stroke, masked]), point: Point(x: 81, y: 40))
        let inMiddle = try sut.report(of: list([outside, picture, stroke, masked]), point: Point(x: 100, y: 40))
        let inMargin = try sut.report(of: list([outside, picture, stroke, masked]), point: Point(x: 20, y: 40))

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
        let report = try sut.report(of: list([cover]), point: Point(x: 10, y: 10))

        // Then
        #expect(report.hits == [
            LocationHit(origin: nil, item: .picture, media: LocatedMedia(file: "/abs/run.mp4", mediaTime: 1.5, point: nil))
        ])
    }

    @Test("a path with an arrowhead is under the point on its line and its head, but not beside the head's tip")
    func hitsArrowShape() throws {
        // Given
        let arrow = DisplayItem(
            content: .path(PathItem(
                geometry: .polyline([Point(x: 10, y: 50), Point(x: 110, y: 50)], isClosed: false),
                fill: nil,
                stroke: PathStroke(width: 4, paint: .color(red), join: .round, cap: .butt, start: .none, end: .arrow)
            )),
            origin: ItemOrigin(place: "clips[2]", id: nil, kind: "shape")
        )

        // When
        let hits = try [Point(x: 50, y: 51), Point(x: 95, y: 56), Point(x: 108, y: 58)].map { point in
            try sut.report(of: list([arrow]), point: point).hits.count
        }

        // Then
        #expect(hits == [1, 1, 0])
    }

    @Test("a trimmed path's arrowhead sits at the end of its drawn stroke, and nothing past it is under the point")
    func hitsTrimmedArrowShape() throws {
        // Given
        // Half of the line is drawn, to x = 60, its head from its base at x = 44 to its tip there.
        let arrow = DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 10, y: 50), Point(x: 110, y: 50)], isClosed: false),
            fill: nil,
            stroke: PathStroke(width: 4, paint: .color(red), join: .round, cap: .butt, start: .none, end: .arrow),
            trim: Trim(start: 0, end: 0.5)
        )))

        // When
        let hits = try [Point(x: 30, y: 51), Point(x: 50, y: 54), Point(x: 90, y: 50)].map { point in
            try sut.report(of: list([arrow]), point: point).hits.count
        }

        // Then
        #expect(hits == [1, 1, 0])
    }

    @Test("a trimmed rect's arrowhead past its outline is under the point, and nothing beside the head is")
    func hitsTrimmedRectArrowhead() throws {
        // Given
        // The rect is 200 round, so a trim to 61 ends 1 below its top right corner, at the head's tip (80, 41). The
        // middle of its base lies 16 back along the stroke, at (65, 40) on the top edge, so the head runs along the
        // chord between them, its upper base corner at (65.5, 32.0), above the stroked rect's top at 38.
        let arrow = DisplayItem(content: .path(PathItem(
            geometry: .rect(Rectangle(x: 20, y: 40, width: 60, height: 40), radius: 0),
            fill: nil,
            stroke: PathStroke(width: 4, paint: .color(red), join: .miter, cap: .butt, start: .none, end: .arrow),
            trim: Trim(start: 0, end: 61.0 / 200)
        )))

        // When
        let hits = try [Point(x: 68, y: 36), Point(x: 75, y: 34)].map { point in
            try sut.report(of: list([arrow]), point: point).hits.count
        }

        // Then
        #expect(hits == [1, 0])
    }

    @Test("a curved path's stroke is under the point on its curve, and not at the middle of its chord")
    func hitsCurvedStroke() throws {
        // Given
        // The segment from (0, 0) to (100, 0), both its tangents (0, 100), bulges down to y = 75 at its middle.
        let curve = DisplayItem(content: .path(PathItem(
            geometry: .path(
                [
                    PathVertex(vertex: Point(x: 0, y: 0), inTangent: Point(x: 0, y: 0), outTangent: Point(x: 0, y: 100)),
                    PathVertex(vertex: Point(x: 100, y: 0), inTangent: Point(x: 0, y: 100), outTangent: Point(x: 0, y: 0))
                ],
                isClosed: false
            ),
            fill: nil,
            stroke: PathStroke(width: 4, paint: .color(red), join: .round, cap: .butt, start: .none, end: .none)
        )))

        // When
        let hits = try [Point(x: 50, y: 74), Point(x: 50, y: 0), Point(x: 50, y: 110)].map { point in
            try sut.report(of: list([curve]), point: point).hits.count
        }

        // Then
        #expect(hits == [1, 0, 0])
    }

    @Test("an open path's fill covers what its segments draw, without the in tangent of its first vertex")
    func leavesOpenPathEndTangentOut() throws {
        // Given
        // The triangle (100, 10), (190, 10), (140, 90) is drawn. The first vertex's in tangent reaches (-300, 10), and
        // the hull with it would hold (50, 40).
        let open = DisplayItem(content: .path(PathItem(
            geometry: .path(Self.triangle, isClosed: false),
            fill: .color(red),
            stroke: nil
        )))

        // When
        let hits = try [Point(x: 50, y: 40), Point(x: 140, y: 40)].map { point in
            try sut.report(of: list([open]), point: point).hits.count
        }

        // Then
        #expect(hits == [0, 1])
    }

    @Test("a closed path's fill covers its closing segment, curved by its first vertex's in tangent")
    func coversClosedPathClosingTangent() throws {
        // Given
        // The closing segment from (140, 90) curves into (100, 10) from (-300, 10), passing (-30, 50) at its middle.
        let closed = DisplayItem(content: .path(PathItem(
            geometry: .path(Self.triangle, isClosed: true),
            fill: .color(red),
            stroke: nil
        )))

        // When
        let hits = try [Point(x: 50, y: 40), Point(x: 140, y: 40)].map { point in
            try sut.report(of: list([closed]), point: point).hits.count
        }

        // Then
        #expect(hits == [1, 1])
    }

    @Test(
        "a sharp add or intersect mask narrows an item to its geometry, and an inverted, feathered or subtract one does not",
        arguments: maskCases
    )
    func narrowsCoverageByMasks(
        masks: [ItemMask],
        point: Point,
        isHit: Bool
    ) throws {
        // Given
        let item = DisplayItem(
            mask: masks,
            content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 200, height: 100), color: red)),
            origin: rect
        )

        // When
        let report = try sut.report(of: list([item]), point: point)

        // Then
        #expect(report.hits.map(\.origin) == (isHit ? [rect] : []))
    }

    @Test("an adjustment covers its list's frame, not carried by its own transform, cut by its mask")
    func coversAdjustmentFrame() throws {
        // Given
        let adjust = DisplayItem(
            transform: AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0),
            mask: mask(Rectangle(x: 100, y: 0, width: 100, height: 100)),
            content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.blur(radius: 2)])])),
            origin: rect
        )

        // When
        let inside = try sut.report(of: list([adjust]), point: Point(x: 150, y: 80))
        let outside = try sut.report(of: list([adjust]), point: Point(x: 50, y: 20))

        // Then
        #expect(inside.hits.map(\.origin) == [rect])
        #expect(outside.hits.isEmpty)
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
            LocationHit(origin: rect, item: .path, media: nil),
            LocationHit(
                origin: clip,
                item: .picture,
                media: LocatedMedia(file: "/abs/run.mp4", mediaTime: 0.5, point: Point(x: 0.1 + 0.2, y: 4))
            ),
            LocationHit(origin: nil, item: .background, media: nil)
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
                  "kind": "rect",
                  "item": "path"
                },
                {
                  "place": "clips[1]#shot",
                  "id": "shot",
                  "kind": "video",
                  "item": "picture",
                  "media": "/abs/run.mp4",
                  "mediaTime": 0.5,
                  "point": [0.3, 4],
                  "page": null
                },
                {
                  "place": null,
                  "id": null,
                  "kind": null,
                  "item": "background"
                }
              ]
            }

            """#)
    }

    // MARK: - Private
    private static func itemMask(
        _ geometry: PathGeometry,
        transform: AffineTransform = .identity,
        feather: Double = 0,
        isInverted: Bool = false,
        mode: MaskMode = .add
    ) -> ItemMask {
        ItemMask(geometry: geometry, transform: transform, feather: feather, isInverted: isInverted, mode: mode)
    }

    // One sharp `add` mask of the rectangle in output pixels.
    private func mask(_ rectangle: Rectangle) -> [ItemMask] {
        [Self.itemMask(.rect(rectangle, radius: 0))]
    }

    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func list(_ items: [DisplayItem]) -> DisplayList {
        DisplayList(size: size, background: transparent, seed: 0, items: items)
    }
}
