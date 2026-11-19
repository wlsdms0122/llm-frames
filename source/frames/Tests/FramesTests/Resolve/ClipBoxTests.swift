//
//  ClipBoxTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// The storyline is `/abs/screen.mp4`, 1206 by 2622, the base theme's `baseWidth`, so the placement padding is 40 output
// pixels. `/abs/card.png` is 1080 by 1350, so a card 300 wide is 375 high.
@Suite("ClipBox Tests")
struct ClipBoxTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner
    // The placement padding of the base theme on the 1206 wide frame of the fixture's screen.
    private static let padding = 96 * (1206 / 1920.0)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a placement sets the box inside the output frame inset by the padding, anchored at the point it names",
        arguments: [
            ("top-left", Point(x: ClipBoxTests.padding, y: ClipBoxTests.padding), Point(x: 0, y: 0)),
            ("top", Point(x: 453, y: ClipBoxTests.padding), Point(x: 150, y: 0)),
            ("top-right", Point(x: 1206 - ClipBoxTests.padding - 300, y: ClipBoxTests.padding), Point(x: 300, y: 0)),
            ("left", Point(x: ClipBoxTests.padding, y: 1123.5), Point(x: 0, y: 187.5)),
            ("center", Point(x: 453, y: 1123.5), Point(x: 150, y: 187.5)),
            ("right", Point(x: 1206 - ClipBoxTests.padding - 300, y: 1123.5), Point(x: 300, y: 187.5)),
            ("bottom-left", Point(x: ClipBoxTests.padding, y: 2622 - ClipBoxTests.padding - 375), Point(x: 0, y: 375)),
            ("bottom", Point(x: 453, y: 2622 - ClipBoxTests.padding - 375), Point(x: 150, y: 375)),
            ("bottom-right", Point(x: 1206 - ClipBoxTests.padding - 300, y: 2622 - ClipBoxTests.padding - 375), Point(x: 300, y: 375))
        ]
    )
    func placesByName(
        placement: String,
        position: Point,
        anchor: Point
    ) throws {
        // Given
        let clip = #"{ "media": "/abs/card.png", "at": [0, 3], "width": 300, "placement": "\#(placement)" }"#

        // When
        let box = try box(of: clip)

        // Then
        #expect(box == ClipBox(size: Size(width: 300, height: 375), position: .value(position), anchor: anchor))
    }

    @Test("a media clip without a placement or position sits in the centre of the output frame")
    func centresMediaByDefault() throws {
        // When
        let box = try box(of: #"{ "media": "/abs/card.png", "at": [0, 3], "width": 300 }"#)

        // Then
        #expect(box?.position == .value(Point(x: 453, y: 1123.5)))
        #expect(box?.anchor == Point(x: 150, y: 187.5))
    }

    @Test("a title without a placement takes its style's, with the style's offset in place of the bottom padding")
    func placesTitleByStyle() throws {
        // When
        let geometry = try geometry(of: #"{ "title": "Hello", "style": "subtitle", "at": [0, 3] }"#)

        // Then
        let size = try #require(geometry.title?.size)
        #expect(geometry.box?.size == size)
        #expect(geometry.box?.position == .value(Point(x: (1206 - size.width) / 2, y: 2622 - 108 * (1206 / 1920.0) - size.height)))
        #expect(geometry.box?.anchor == Point(x: size.width / 2, y: size.height))
    }

    @Test(
        "a position puts the anchor point there, and the box's top left is written",
        arguments: [
            ("top-left", Point(x: 600, y: 1000)),
            ("top", Point(x: 450, y: 1000)),
            ("top-right", Point(x: 300, y: 1000)),
            ("left", Point(x: 600, y: 812.5)),
            ("center", Point(x: 450, y: 812.5)),
            ("right", Point(x: 300, y: 812.5)),
            ("bottom-left", Point(x: 600, y: 625)),
            ("bottom", Point(x: 450, y: 625)),
            ("bottom-right", Point(x: 300, y: 625))
        ]
    )
    func anchorsPosition(
        anchor: String,
        topLeft: Point
    ) throws {
        // Given
        let clip = #"{ "media": "/abs/card.png", "at": [0, 3], "width": 300, "position": [600, 1000], "anchor": "\#(anchor)" }"#

        // When
        let box = try box(of: clip)

        // Then
        #expect(box?.position == .value(topLeft))
        #expect(box?.anchor == Point(x: 600 - topLeft.x, y: 1000 - topLeft.y))
    }

    @Test("a keyframed position stays keyframes in sequence time, each value moved to the top left")
    func movesKeyframedPosition() throws {
        // Given
        let clip = #"""
            { "media": "/abs/card.png", "at": [0, 3], "width": 300,
              "keyframes": [ { "at": 0, "position": [100, 200] }, { "at": 1, "position": [300, 400], "ease": "ease-in" } ] }
            """#

        // When
        let box = try box(of: clip)

        // Then
        #expect(box?.position == .keyframes([
            PropertyKeyframe(index: 0, at: 0, value: Point(x: -50, y: 12.5), ease: .linear),
            PropertyKeyframe(index: 1, at: 1, value: Point(x: 150, y: 212.5), ease: .easeIn)
        ]))
    }

    @Test("a parented clip's top left stays in its parent's space, less its anchor")
    func keepsParentedPositionInMedia() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "media": "/abs/card.png", "at": [0, 3], "parent": "screen", "width": 200, "height": 100,
                  "position": [500, 600], "anchor": "bottom-right" } ] } ] }
            """#

        // When
        let box = try plan(document).clips[0].box

        // Then
        #expect(box == ClipBox(size: Size(width: 200, height: 100), position: .value(Point(x: 300, y: 500)), anchor: Point(x: 200, y: 100)))
    }

    @Test(
        "a media clip's box follows the aspect of its first crop for a missing side, whatever its conform",
        arguments: [
            (#""width": 300"#, Size(width: 300, height: 150)),
            (#""height": 300"#, Size(width: 600, height: 300)),
            (#""width": 300, "height": 300, "conform": "fit""#, Size(width: 300, height: 300)),
            (#""width": 300, "height": 300, "conform": "fill""#, Size(width: 300, height: 300)),
            (#""conform": "fill""#, Size(width: 1206, height: 603))
        ]
    )
    func sizesMediaBox(
        keys: String,
        size: Size
    ) throws {
        // Given
        let clip = #"""
            { "media": "/abs/card.png", "at": [0, 3], \#(keys),
              "keyframes": [ { "at": 1, "crop": [0, 0, 200, 200] }, { "at": 0, "crop": [0, 0, 400, 200] } ] }
            """#

        // When
        let box = try box(of: clip)

        // Then
        #expect(box?.size == size)
    }

    @Test("a media clip given neither width nor height fits the output frame, scaled up or down")
    func fitsMediaToFrame() throws {
        // Given
        let tall = #"{ "media": "/abs/card.png", "at": [0, 3] }"#
        let small = #"{ "media": "/abs/card.png", "at": [0, 3], "crop": [0, 0, 201, 20] }"#

        // When
        let tallBox = try box(of: tall)
        let smallBox = try box(of: small)

        // Then
        #expect(tallBox?.size == Size(width: 1206, height: 1507.5))
        #expect(smallBox?.size == Size(width: 1206, height: 120))
    }

    @Test(
        "every crop of a media clip conforms to its box by its conform, so the box holds still while the crop moves",
        arguments: [
            (Conform.fit, Rectangle(x: -100, y: 0, width: 400, height: 200)),
            (Conform.fill, Rectangle(x: 0, y: 50, width: 200, height: 100))
        ]
    )
    func conformsCropsToBox(
        conform: Conform,
        second: Rectangle
    ) throws {
        // Given
        let clip = #"""
            { "media": "/abs/card.png", "at": [0, 3], "width": 300, "conform": "\#(conform.rawValue)",
              "keyframes": [ { "at": 0, "crop": [0, 0, 400, 200] }, { "at": 1, "crop": [0, 0, 200, 200] } ] }
            """#

        // When
        let media = try geometry(of: clip).appearance.media

        // Then
        #expect(media?.conform == conform)
        #expect(media?.crop == .keyframes([
            PropertyKeyframe(index: 0, at: 0, value: Rectangle(x: 0, y: 0, width: 400, height: 200), ease: .linear),
            PropertyKeyframe(index: 1, at: 1, value: second, ease: .linear)
        ]))
    }

    @Test("a shape is placed by its area and has no box of its own")
    func leavesShapeWithoutBox() throws {
        // When
        let box = try box(of: #"{ "shape": "rect", "stroke": { "width": 8 }, "at": [0, 3], "area": [10, 10, 100, 100] }"#)

        // Then
        #expect(box == nil)
    }

    @Test("a clip with both a placement and a position stops")
    func refusesPlacementWithPosition() throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try box(of: #"{ "media": "/abs/card.png", "at": [0, 3], "placement": "top", "position": [10, 10] }"#)
        }
        #expect(error == .placementWithPosition(place: Place.root.appending(key: "clips").appending(index: 0), kind: .clip(.media(.image))))
    }

    @Test("a parented media clip without a position stops, since it has no default place")
    func refusesParentedClipWithoutPosition() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "media": "/abs/card.png", "at": [0, 3], "parent": "screen" } ] } ] }
            """#
        let place = Place.root.appending(key: "storyline").appending(index: 0, id: "screen").appending(key: "connected")
            .appending(index: 0)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == .parentWithoutPosition(place: place, kind: .clip(.media(.image))))
    }

    @Test(
        "a parented box clip with a placement or without a position stops, connected or sequence clip alike",
        arguments: [
            (
                #"{ "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [ { "title": "a", "style": "subtitle", "parent": "screen", "placement": "top" } ] } ] }"#,
                #"storyline[0]#screen.connected[0] (title): a parented clip cannot take "placement", since placement names the frame and not its parent's space"#
            ),
            (
                #"{ "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4" } ], "clips": [ { "at": [0, 1], "media": "/abs/card.png", "parent": "screen", "placement": "top" } ] }"#,
                #"clips[0] (image): a parented clip cannot take "placement", since placement names the frame and not its parent's space"#
            ),
            (
                #"{ "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4" } ], "clips": [ { "at": [0, 1], "title": "a", "style": "title", "parent": "screen" } ] }"#,
                #"clips[0] (title): a parented clip has no default place, so it needs "position""#
            )
        ]
    )
    func refusesParentedPlacement(
        document: String,
        message: String
    ) throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == message)
    }

    @Test("a sequence clip parented to another clip keeps its top left in that clip's space")
    func placesSequenceClipInParent() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [
                { "id": "card", "media": "/abs/card.png", "at": [0, 3], "width": 300, "position": [600, 1300] },
                { "media": "/abs/card.png", "at": [0, 3], "parent": "card", "width": 200, "height": 100,
                  "position": [500, 600], "anchor": "top-left" } ] }
            """#

        // When
        let box = try plan(document).clips[1].box

        // Then
        #expect(box == ClipBox(size: Size(width: 200, height: 100), position: .value(Point(x: 500, y: 600)), anchor: Point(x: 0, y: 0)))
    }

    @Test("a media clip whose crop, conformed to its box, lies wholly outside its media stops, since it is never visible")
    func refusesCropOutsideMedia() throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try box(of: #"{ "media": "/abs/card.png", "at": [0, 3], "width": 300, "height": 300, "crop": [2000, 100, 200, 100] }"#)
        }
        #expect(error == .cropOutsideMedia(
            place: Place.root.appending(key: "clips").appending(index: 0).appending(key: "crop"),
            kind: .clip(.media(.image)),
            crop: Rectangle(x: 2000, y: 50, width: 200, height: 200),
            size: Size(width: 1080, height: 1350)
        ))
        #expect(error?.description == "clips[0].crop (image): never visible, since its crop conformed to its box is [2000, 50, 200, 200], which lies wholly outside its media of 1080x1350")
    }

    @Test("a title whose style gives no placement stops without a placement or a position, since it has no default place")
    func refusesTitleWithoutPlacement() throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try labelBox(of: #"{ "title": "Hello", "style": "label", "at": [0, 3] }"#)
        }
        #expect(error == .titleWithoutPlacement(
            place: Place.root.appending(key: "clips").appending(index: 0),
            kind: .clip(.title),
            style: "label"
        ))
        #expect(error?.description == #"clips[0] (title): style "label" gives no placement, so the title needs "placement" or "position""#)
    }

    @Test("a title in a style without a placement is placed by its own placement or position")
    func placesUnstyledTitle() throws {
        // When
        let placed = try labelBox(of: #"{ "title": "Hello", "style": "label", "at": [0, 3], "placement": "top-left" }"#)
        let positioned = try labelBox(of: #"{ "title": "Hello", "style": "label", "at": [0, 3], "position": [100, 100] }"#)

        // Then
        #expect(placed?.position == .value(Point(x: ClipBoxTests.padding, y: ClipBoxTests.padding)))
        #expect(positioned != nil)
    }

    // MARK: - Private
    private func box(of clip: String) throws -> ClipBox? {
        try geometry(of: clip).box
    }

    // A clip in a sequence whose theme adds the style `label`, which gives no placement.
    private func labelBox(of clip: String) throws -> ClipBox? {
        let document = #"""
            { "kind": "sequence", "theme": { "styles": { "label": { "size": 36 } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip) ] }
            """#

        return try plan(document).clips[0].box
    }

    private func geometry(of clip: String) throws -> ClipGeometry {
        try plan(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip) ] }"#).clips[0]
    }

    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }
}
