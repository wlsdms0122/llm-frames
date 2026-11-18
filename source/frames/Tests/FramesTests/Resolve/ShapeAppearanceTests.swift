//
//  ShapeAppearanceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// Shapes are sequence clips over `/abs/screen.mp4` in a 960 by 540 frame, so theme lengths are half their written
// size. The theme holds the shape styles `outline` and `pointer`.
@Suite("ShapeAppearance Tests")
struct ShapeAppearanceTests {
    // MARK: - Property
    private static let theme = ##"""
        { "colors": { "brand": "#123456" },
          "shadow": { "radius": 20, "offset": [0, 8], "color": "#00000080" },
          "shapes": {
            "outline": { "fill": "brand", "stroke": { "width": 8, "color": "#ED2929", "end": "arrow" }, "radius": 18,
                         "outset": 6, "shadow": true },
            "pointer": { "stroke": { "width": 10 } } } }
        """##

    private let sut = Fixture.sequencePlanner

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a shape stops where FRAMES-11 says, naming its place",
        arguments: [
            (
                #"{ "shape": "rect", "area": [0, 0, 10, 10], "width": 10, "height": 10, "fill": "accent" }"#,
                #"clips[0] (rect): a rect or ellipse is given by "area" or by "width" and "height", and this one writes both"#
            ),
            (
                #"{ "shape": "ellipse", "fill": "accent" }"#,
                #"clips[0] (ellipse): a rect or ellipse needs "area", or "width" and "height""#
            ),
            (
                #"{ "shape": "rect", "width": 10, "fill": "accent" }"#,
                #"clips[0] (rect): missing key "height""#
            ),
            (
                #"{ "shape": "ellipse", "fill": "accent", "keyframes": [ { "at": 0, "height": 10 } ] }"#,
                #"clips[0] (ellipse): missing key "width""#
            ),
            (
                #"{ "shape": "path", "fill": "accent" }"#,
                #"clips[0] (path): missing key "points""#
            ),
            (
                #"{ "shape": "path", "fill": "accent", "keyframes": [ { "at": 0, "points": [[0, 0], [1, 1]] }, { "at": 1, "points": [[0, 0], [1, 1], [2, 2]] } ] }"#,
                #"clips[0].keyframes[1].points (path): the keyframes of "points" hold 2 and 3 points, and points interpolate one by one, so every value has the same number"#
            ),
            (
                #"{ "shape": "rect", "area": [0, 0, 10, 10] }"#,
                #"clips[0] (rect): the shape has neither a fill nor a stroke after its style, so it draws nothing"#
            ),
            (
                #"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "outline", "fill": false, "stroke": false }"#,
                #"clips[0] (rect): the shape has neither a fill nor a stroke after its style, so it draws nothing"#
            ),
            (
                #"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "box" }"#,
                #"clips[0].style (rect): shape style "box" is not in shapes, which hold "outline", "pointer""#
            ),
            (
                #"{ "shape": "rect", "area": [0, 0, 10, 10], "fill": "ink" }"#,
                #"clips[0].fill (rect): colour "ink" is not in colors"#
            ),
            (
                #"{ "shape": "path", "points": [[0, 0], [1, 1]], "stroke": { "width": 2, "color": "ink" } }"#,
                #"clips[0].stroke.color (path): colour "ink" is not in colors"#
            ),
            (
                #"{ "shape": "rect", "area": [0, 0, 10, 10], "placement": "top", "fill": "accent" }"#,
                #"clips[0] (rect): "placement" places a box given by "width" and "height", and a shape given by "area" is placed by its area"#
            )
        ]
    )
    func stopsAsFrames11Says(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = document(clip)

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(document) }
        #expect(error.map { "\($0)" } == message)
    }

    @Test("a shape style the base theme does not hold stops, saying the theme holds none")
    func stopsOnStyleOfBaseTheme() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ { "shape": "rect", "area": [0, 0, 10, 10], "style": "outline", "at": [0, 1] } ] }
            """#

        // When, Then
        let error = #expect(throws: ThemeError.self) { try plan(document) }
        #expect(error?.description == #"clips[0].style (rect): shape style "outline" is not in shapes, which hold none"#)
    }

    @Test("a path's point found by text stops on a clip whose space is output pixels")
    func stopsOnTextPointInOutputPixels() throws {
        // Given
        let document = document(#"{ "shape": "path", "points": [[0, 0], { "area": { "text": "Total" }, "point": "left" }], "fill": "accent" }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description.hasPrefix("clips[0].points[1] (path): ") == true, "\(error?.description ?? "no error")")
    }

    @Test("a style gives every property the clip does not write, its lengths scaled and its shadow the theme's")
    func takesStyle() throws {
        // When
        let shape = try appearance(#"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "outline" }"#)

        // Then
        #expect(shape == ShapeAppearance(
            kind: .rect,
            geometry: .area(outset: 3),
            anchor: nil,
            radius: .value(9),
            trim: .value(.whole),
            fill: Color(written: "#123456"),
            stroke: PathStroke(width: 4, color: Color(written: "#ED2929"), join: .round, cap: .butt, start: .none, end: .arrow),
            shadow: DropShadow(radius: 10, offset: Point(x: 0, y: 4), color: Color(written: "#00000080"))
        ))
    }

    @Test("a key on the clip wins over its style's whole: a stroke replaces the style's, and false turns one off")
    func letsClipKeyWinWhole() throws {
        // When
        let shape = try appearance(#"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "outline", "stroke": { "width": 2 }, "fill": false,
              "shadow": { "radius": 4 }, "radius": 0, "outset": 0 }
            """#)

        // Then
        #expect(shape.stroke == PathStroke(width: 1, color: MergedTheme.base.color("accent"), join: .round, cap: .butt, start: .none, end: .none))
        #expect(shape.fill == nil)
        #expect(shape.shadow == DropShadow(radius: 2, offset: Point(x: 0, y: 4), color: Color(written: "#00000080")))
        #expect(shape.radius == .value(0))
        #expect(shape.geometry == .area(outset: 0))
    }

    @Test("a shape without a style takes nothing from the theme but colour names, and its stroke the stroke defaults")
    func takesOnlyColourNamesWithoutStyle() throws {
        // When
        let shape = try appearance(#"{ "shape": "ellipse", "area": [0, 0, 10, 10], "stroke": { "width": 4 }, "fill": "brand" }"#)

        // Then
        #expect(shape == ShapeAppearance(
            kind: .ellipse,
            geometry: .area(outset: 0),
            anchor: nil,
            radius: .value(0),
            trim: .value(.whole),
            fill: Color(written: "#123456"),
            stroke: PathStroke(width: 2, color: MergedTheme.base.color("accent"), join: .round, cap: .butt, start: .none, end: .none),
            shadow: nil
        ))
    }

    @Test("a rect by its width and height is a box grown by its outset, placed as a media clip's box")
    func placesBoxShape() throws {
        // When
        let plan = try plan(document(#"{ "shape": "rect", "width": 200, "height": 100, "outset": 10, "placement": "bottom-right", "fill": "accent" }"#))

        // Then
        // The outset of 5 grows the box to 210 by 110, inset from the bottom right by the placement padding.
        let padding = 96 * 0.5
        #expect(plan.clips[0].appearance.shape?.geometry == .box(width: .value(200), height: .value(100), outset: 5))
        #expect(plan.clips[0].box == ClipBox(
            size: Size(width: 210, height: 110),
            position: .value(Point(x: 960 - padding - 210, y: 540 - padding - 110)),
            anchor: Point(x: 210, y: 110)
        ))
    }

    @Test("an ellipse by its width and height turns about its anchor point, which its position puts where it names")
    func placesBoxShapeByPosition() throws {
        // When
        let plan = try plan(document(#"{ "shape": "ellipse", "width": 200, "height": 100, "anchor": "top-left", "position": [300, 200], "fill": "accent" }"#))

        // Then
        #expect(plan.clips[0].box == ClipBox(
            size: Size(width: 200, height: 100),
            position: .value(Point(x: 300, y: 200)),
            anchor: Point(x: 0, y: 0)
        ))
    }

    @Test("a shape placed by its area writes its area as written and its outset in output pixels, and names its anchor on its area")
    func writesGeometryShape() throws {
        // When
        let shape = try resolvedShape(#"{ "shape": "rect", "area": [100, 100, 200, 100], "outset": 20, "anchor": "bottom-right", "position": [500, 300], "fill": "accent" }"#)

        // Then
        let area = Rectangle(x: 100, y: 100, width: 200, height: 100)
        #expect(shape.geometry == .area([Keyframe(at: 0, value: area)], outset: 10))
        #expect(shape.anchor == NamedPoint(area: area, name: "bottom-right"))
        #expect(shape.position == [Keyframe(at: 0, value: Point(x: 500, y: 300))])
    }

    @Test("a path's points are found as positions are, a named point of an area found by text in its parent's media")
    func findsPathPoints() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "connected": [
                { "shape": "rect", "area": { "text": "Total" }, "parent": "screen", "fill": "accent" },
                { "shape": "path", "parent": "screen", "points": [[10, 20], { "area": { "text": "Total" }, "point": "left" }],
                  "closed": true, "stroke": { "width": 4, "end": "arrow" } } ] } ] }
            """#

        // When
        let clips = try ResolvedSequence(plan: plan(document), hashes: FileHashTable()).clips

        // Then
        guard case let .shape(rect) = clips[0].content, case let .shape(path) = clips[1].content else {
            Issue.record("both clips are shapes")
            return
        }
        guard case let .area(area, _) = rect.geometry, case let .points(points, isClosed) = path.geometry else {
            Issue.record("the rect is placed by its area and the path by its points")
            return
        }
        let total = try #require(area.first?.value)
        #expect(points.map(\.value) == [[Point(x: 10, y: 20), total.point(named: "left")]])
        #expect(isClosed)
        #expect(path.anchor == nil)
        #expect(clips[1].box == nil)
    }

    // MARK: - Private
    private func document(_ clip: String) -> String {
        #"""
        { "kind": "sequence", "format": { "size": [960, 540] }, "theme": \#(Self.theme),
          "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip.dropLast(2)), "at": [0, 1] } ] }
        """#
    }

    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    private func appearance(_ clip: String) throws -> ShapeAppearance {
        try #require(try plan(document(clip)).clips[0].appearance.shape)
    }

    private func resolvedShape(_ clip: String) throws -> ResolvedShape {
        let clips = try ResolvedSequence(plan: plan(document(clip)), hashes: FileHashTable()).clips
        guard case let .shape(shape) = clips.first?.content else {
            Issue.record("the clip is a shape")
            return ResolvedShape(area: [], fill: nil)
        }

        return shape
    }
}
