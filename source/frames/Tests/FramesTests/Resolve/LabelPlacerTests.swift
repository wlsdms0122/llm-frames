//
//  LabelPlacerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// The output and the content rect are the 1206x2622 frame of `/abs/screen.mp4`, so without a crop a parented area lands
// where it is in the picture. The label is 200 wide and 60 high, and the base theme tries right, bottom, left, top.
@Suite("LabelPlacer Tests")
struct LabelPlacerTests {
    // MARK: - Property
    private static let solidThenScreen = ##"""
        { "kind": "sequence", "storyline": [
            { "media": "/abs/screen.mp4", "in": 1, "out": 3,
              "connected": [ { "shape": "box", "area": [0, 0, 1, 1], "at": [2.6, 3], "label": "a" } ] },
            { "solid": "#000000", "duration": 2, "transition": { "preset": "flash", "seconds": 1 },
              "connected": [ { "shape": "box", "area": [0, 0, 1, 1], "label": "a" } ] } ],
          "clips": [ { "shape": "box", "area": [0, 0, 1, 1], "at": [1.6, 3], "label": "a" } ] }
        """##

    private let sut = LabelPlacer()
    private let text = TextLayout(size: Size(width: 200, height: 60), lineCount: 1, runs: [], stroke: nil, background: nil)
    private let screen = Picture(
        name: "/abs/screen.mp4",
        source: .mediaFile("/abs/screen.mp4"),
        size: Size(width: 1206, height: 2622)
    )
    private let format = FormatPlan(
        size: Size(width: 1206, height: 2622),
        content: Rectangle(x: 0, y: 0, width: 1206, height: 2622),
        conform: .fit,
        background: Color(written: "#FFFFFF"),
        fps: 30,
        duration: 4
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a label sits outside the shape's box, touching its side and centred along it, on the first side that fits",
        arguments: [
            (Rectangle(x: 100, y: 100, width: 200, height: 40), Side.right),
            (Rectangle(x: 806, y: 100, width: 200, height: 40), Side.right),
            (Rectangle(x: 807, y: 100, width: 200, height: 40), Side.bottom),
            (Rectangle(x: 100, y: 10, width: 200, height: 40), Side.right),
            (Rectangle(x: 100, y: 9, width: 200, height: 40), Side.bottom),
            (Rectangle(x: 900, y: 2552, width: 300, height: 40), Side.left),
            (Rectangle(x: 0, y: 2552, width: 1206, height: 40), Side.top)
        ]
    )
    func choosesFirstSideThatFits(
        area: Rectangle,
        side: Side
    ) throws {
        // Given
        let document = connected(#"{ "shape": "box", "area": [0, 0, 1, 1], "label": "a" }"#)

        // When
        let label = try place(.value(found(area, at: 1)), document: document)

        // Then
        #expect(label.side == side)
        #expect(label.text == text)
    }

    @Test("the sides and their order are the theme's")
    func takesSidesFromTheme() throws {
        // Given
        let document = connected(
            #"{ "shape": "box", "area": [0, 0, 1, 1], "label": "a" }"#,
            theme: #"{ "shapes": { "label": { "sides": ["top", "left"] } } }"#
        )

        // When
        let label = try place(.value(found(Rectangle(x: 300, y: 300, width: 200, height: 40), at: 1)), document: document)

        // Then
        #expect(label.side == .top)
    }

    @Test("a label that fits on no side stops, naming the sides tried")
    func refusesNoRoom() throws {
        // Given
        let document = connected(
            #"{ "shape": "box", "area": [0, 0, 1, 1], "label": "Total" }"#,
            theme: #"{ "shapes": { "label": { "sides": ["left", "top"] } } }"#
        )
        let area = Rectangle(x: 100, y: 10, width: 200, height: 40)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try place(.value(found(area, at: 1)), document: document) }
        #expect(error?.description == #"""
            storyline[0].connected[0].label (box): the label "Total" fits inside the content rect on none of the \#
            sides left, top
            """#)
    }

    @Test("a shape without an area is measured against the content rect it covers, so its label has no room")
    func refusesShapeWithoutArea() throws {
        // Given
        let document = connected(#"{ "shape": "dim", "label": "a" }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try place(nil, document: document) }
        #expect(error?.description == #"""
            storyline[0].connected[0].label (dim): the label "a" fits inside the content rect on none of the sides \#
            right, bottom, left, top
            """#)
    }

    @Test("a sequence clip's label is measured against the output frame, not the content rect")
    func measuresSequenceClipInOutput() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "theme": { "shapes": { "label": { "sides": ["top"] } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "shape": "box", "area": [0, 0, 1, 1], "at": [0, 1], "label": "a" } ] }
            """#
        let inset = FormatPlan(
            size: format.size,
            content: Rectangle(x: 0, y: 200, width: 1206, height: 2422),
            conform: .fit,
            background: format.background,
            fps: format.fps,
            duration: format.duration
        )

        // When
        let label = try place(
            .value(found(Rectangle(x: 100, y: 210, width: 200, height: 40), at: 0)),
            document: document,
            format: inset
        )

        // Then
        #expect(label.side == .top)
    }

    @Test(
        "an arrow's box runs from its tail to its tip at the middle of the side it points from",
        arguments: [
            (#"{ "shape": "box", "area": [0, 0, 1, 1], "label": "a" }"#, Side.right),
            (#"{ "shape": "arrow", "side": "right", "area": [0, 0, 1, 1], "label": "a" }"#, Side.bottom),
            (#"{ "shape": "arrow", "side": "top", "area": [0, 0, 1, 1], "label": "a" }"#, Side.right)
        ]
    )
    func measuresArrowBox(
        clip: String,
        side: Side
    ) throws {
        // Given
        let document = connected(clip)

        // When
        let label = try place(.value(found(Rectangle(x: 700, y: 300, width: 200, height: 40), at: 1)), document: document)

        // Then
        #expect(label.side == side)
    }

    @Test(
        "the side is measured at the first visible instant out of every transition, else the middle of the window, and a sequence clip's at its first",
        arguments: [(1, 2.5), (0, 1.8), (2, 1.6)]
    )
    func measuresAtInstant(
        index: Int,
        instant: Double
    ) throws {
        // When
        let label = try place(
            .value(found(Rectangle(x: 100, y: 100, width: 200, height: 40), at: 1)),
            document: Self.solidThenScreen,
            index: index
        )

        // Then
        #expect(label.instant == instant)
    }

    @Test(
        "a keyframed area is measured where its keyframes and eases put it at the instant, without animation",
        arguments: [(1600.0, Ease.linear, Side.right), (1700.0, Ease.linear, Side.bottom), (1000.0, Ease.easeOut, Side.bottom)]
    )
    func interpolatesKeyframes(
        end: Double,
        ease: Ease,
        side: Side
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "shape": "box", "area": [0, 0, 1, 1], "at": [1, 3], "label": "a" } ] }
            """#
        let area = PropertyValue<FoundArea>.keyframes([
            TimedValue(index: 0, at: 0, value: found(Rectangle(x: 0, y: 100, width: 200, height: 40), at: 0), ease: ease),
            TimedValue(index: 1, at: 2, value: found(Rectangle(x: end, y: 100, width: 200, height: 40), at: 2), ease: .linear)
        ])

        // When
        let label = try place(area, document: document)

        // Then
        #expect(label.side == side)
    }

    @Test("a tracked area is brought back at the time it was found and carried by the motion at the instant")
    func carriesByTrack() throws {
        // Given
        let document = connected(#"{ "shape": "box", "area": [0, 0, 1, 1], "at": [1.5, 3], "label": "a" }"#)
        let area = Fixture.total
        let track = Track(target: area, mediaTime: 1, frames: [
            TrackedFrame(time: 1, rectangle: area),
            TrackedFrame(time: 1.5, rectangle: Rectangle(x: area.x + 800, y: area.y, width: area.width, height: area.height))
        ])

        // When
        let still = try place(.value(found(area, at: 1)), document: document)
        let tracked = try place(.value(found(area, at: 1)), document: document, track: track)

        // Then
        #expect(still.side == .right)
        #expect(tracked.side == .bottom)
    }

    @Test(
        "a parented area is shown through its storyline clip's crop conformed into the content rect",
        arguments: [
            (nil, Side.right),
            (Rectangle(x: 301.5, y: 655.5, width: 603, height: 1311), Side.bottom),
            (Rectangle(x: 301.5, y: 0, width: 603, height: 2622), Side.right)
        ]
    )
    func showsThroughCrop(
        crop: Rectangle?,
        side: Side
    ) throws {
        // Given
        let document = connected(#"{ "shape": "box", "area": [0, 0, 1, 1], "label": "a" }"#)

        // When
        let label = try place(
            .value(found(Rectangle(x: 710, y: 700, width: 100, height: 20), at: 1)),
            document: document,
            crop: crop.map { .value(found($0, at: 1)) }
        )

        // Then
        #expect(label.side == side)
    }

    // MARK: - Private
    private func connected(
        _ clip: String,
        theme: String? = nil
    ) -> String {
        let theme = theme.map { #""theme": \#($0), "# } ?? ""
        return #"""
            { "kind": "sequence", \#(theme)"storyline": [
                { "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [ \#(clip) ] } ] }
            """#
    }

    // The clip's found area is given, and its storyline clip shows the whole of `/abs/screen.mp4` unless `crop` says.
    private func place(
        _ area: PropertyValue<FoundArea>?,
        document: String,
        index: Int = 0,
        track: Track? = nil,
        crop: PropertyValue<FoundArea>? = nil,
        format: FormatPlan? = nil
    ) throws -> LabelPlan {
        let time = try Fixture.planner.plan(document: Fixture.json(document))
        let clip = time.clips[index]
        let written = (time.sequence.storyline.flatMap(\.connected) + time.sequence.clips)[index]
        let parent = clip.storyline.flatMap { owner in
            clip.isParented
                ? ParentPicture(
                    plan: time.storyline[owner],
                    geometry: StorylineGeometry(crop: crop, track: nil, nested: nil),
                    picture: screen
                )
                : nil
        }

        return try sut.label(
            text,
            of: clip,
            written: written,
            area: area,
            track: track,
            parent: parent,
            storyline: time.storyline,
            format: format ?? self.format,
            theme: time.theme
        )
    }

    private func found(
        _ rectangle: Rectangle,
        at mediaTime: Double
    ) -> FoundArea {
        FoundArea(rectangle: rectangle, target: rectangle, isBand: false, mediaTime: mediaTime, lines: [])
    }
}
