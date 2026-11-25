//
//  ShapeAppearanceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames
import FramesTestMedia

// Shapes are sequence clips over `/abs/screen.mp4` in a 960 by 540 frame, so theme lengths are half their written
// size. The theme holds the shape styles `outline` and `pointer`.
@Suite("ShapeAppearance Tests")
struct ShapeAppearanceTests {
    // MARK: - Property
    private static let theme = ##"""
        { "colors": { "brand": "#123456" },
          "shadow": { "radius": 20, "offset": [0, 8], "color": "#00000080" },
          "shapes": {
            "outline": { "fill": "brand", "stroke": { "width": 8, "color": "#ED2929", "end": "frames/arrow" }, "radius": 18,
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
                #"{ "kind": "rect", "area": [0, 0, 10, 10], "width": 10, "height": 10, "fill": "accent" }"#,
                #"clips[0] (rect): a rect or ellipse is given by "area" or by "width" and "height", and this one writes both"#
            ),
            (
                #"{ "kind": "ellipse", "fill": "accent" }"#,
                #"clips[0] (ellipse): a rect or ellipse needs "area", or "width" and "height""#
            ),
            (
                #"{ "kind": "rect", "width": 10, "fill": "accent" }"#,
                #"clips[0] (rect): missing key "height""#
            ),
            (
                #"{ "kind": "ellipse", "fill": "accent", "keyframes": [ { "at": 0, "height": 10 } ] }"#,
                #"clips[0] (ellipse): missing key "width""#
            ),
            (
                #"{ "kind": "path", "fill": "accent" }"#,
                #"clips[0] (path): missing key "points""#
            ),
            (
                #"{ "kind": "path", "fill": "accent", "keyframes": [ { "at": 0, "points": [[0, 0], [1, 1]] }, { "at": 0.5, "points": [[0, 0], [1, 1], [2, 2]] } ] }"#,
                #"clips[0].keyframes[1].points (path): the values of "points" hold 2 and 3 vertices, and a path interpolates vertex by vertex, so every value has the same number"#
            ),
            (
                #"{ "kind": "path", "fill": "accent", "points": [[0, 0], [1, 1]], "keyframes": [ { "at": 0.5, "points": [{ "inTangent": [1, 0] }, {}, {}] } ] }"#,
                #"clips[0].keyframes[0].points (path): the values of "points" hold 2 and 3 vertices, and a path interpolates vertex by vertex, so every value has the same number"#
            ),
            (
                #"{ "kind": "path", "fill": "accent", "keyframes": [ { "at": 0, "points": [[0, 0], { "inTangent": [1, 0] }] }, { "at": 0.5, "points": [[0, 0], {}] } ] }"#,
                #"clips[0].keyframes[0].points[1] (path): missing key "vertex""#
            ),
            (
                #"{ "kind": "rect", "area": [0, 0, 10, 10] }"#,
                #"clips[0] (rect): the shape has neither a fill nor a stroke after its style, so it draws nothing"#
            ),
            (
                #"{ "kind": "rect", "area": [0, 0, 10, 10], "style": "outline", "fill": false, "stroke": false }"#,
                #"clips[0] (rect): the shape has neither a fill nor a stroke after its style, so it draws nothing"#
            ),
            (
                #"{ "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "stroke": { "width": 2, "align": "inside" } }"#,
                #"clips[0].stroke (path): a stroke "inside" its outline needs a closed outline, and the path is open"#
            ),
            (
                #"{ "kind": "rect", "area": [0, 0, 10, 10], "style": "outline", "stroke": { "align": "outside" } }"#,
                #"clips[0].stroke (rect): a stroke "outside" its outline takes no arrowhead, which lies across the outline with its tip at the end while the stroke lies on one side of it"#
            ),
            (
                #"{ "kind": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "align": "inside", "start": { "preset": "frames/bar", "scale": 2 } } }"#,
                #"clips[0].stroke (rect): a stroke "inside" its outline takes no arrowhead, which lies across the outline with its tip at the end while the stroke lies on one side of it"#
            ),
            (
                #"{ "kind": "ellipse", "area": [0, 0, 10, 10], "stroke": { "width": 2, "align": "outside", "end": "frames/circle" } }"#,
                #"clips[0].stroke (ellipse): a stroke "outside" its outline takes no arrowhead, which lies across the outline with its tip at the end while the stroke lies on one side of it"#
            ),
            (
                #"{ "kind": "path", "points": [[0, 0], [10, 0]], "stroke": { "width": 2, "end": "arrow" } }"#,
                #"clips[0].stroke.end (path): unknown head preset "arrow". Did you mean "frames/arrow"? A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#
            ),
            (
                #"{ "kind": "path", "points": [[0, 0], [10, 0]], "stroke": { "width": 2, "start": { "preset": "mine/hook", "scale": 2 } } }"#,
                #"clips[0].stroke.start (path): unknown head preset "mine/hook". The pack "mine" holds no head presets"#
            ),
            (
                #"{ "kind": "path", "points": [[0, 0], [10, 0]], "style": "pointer", "stroke": { "end": "frames/dot" } }"#,
                #"clips[0].stroke.end (path): unknown head preset "frames/dot". The pack "frames" holds the head presets frames/arrow, frames/bar, frames/circle, frames/diamond, frames/line-arrow, frames/square"#
            ),
            (
                #"{ "kind": "rect", "area": [0, 0, 10, 10], "style": "box" }"#,
                #"clips[0].style (rect): shape style "box" is not in shapes, which hold "outline", "pointer""#
            ),
            (
                #"{ "kind": "rect", "area": [0, 0, 10, 10], "fill": "ink" }"#,
                #"clips[0].fill (rect): colour "ink" is not in colors"#
            ),
            (
                #"{ "kind": "path", "points": [[0, 0], [1, 1]], "stroke": { "width": 2, "color": "ink" } }"#,
                #"clips[0].stroke.color (path): colour "ink" is not in colors"#
            ),
            (
                #"{ "kind": "rect", "area": [0, 0, 10, 10], "placement": "top", "fill": "accent" }"#,
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
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "style": "outline", "at": [0, 1] } ] }
            """#

        // When, Then
        let error = #expect(throws: ThemeError.self) { try plan(document) }
        #expect(error?.description == #"clips[0].style (rect): shape style "outline" is not in shapes, which hold none"#)
    }

    @Test("a style gives every property the clip does not write, its lengths scaled and its shadow the theme's")
    func takesStyle() throws {
        // When
        let shape = try appearance(#"{ "kind": "rect", "area": [0, 0, 10, 10], "style": "outline" }"#)

        // Then
        #expect(shape == ShapeAppearance(
            kind: .rect,
            geometry: .area(outset: 3, anchor: nil),
            radius: .corners(9),
            trim: .value(.whole),
            fill: .fill(Color(written: "#123456")),
            stroke: .stroke(PathStroke(width: 4, paint: .color(Color(written: "#ED2929")), join: .round, cap: .butt, start: .none, end: .arrow)),
            shadow: .shadow(DropShadow(radius: 10, offset: Point(x: 0, y: 4), color: Color(written: "#00000080")))
        ))
    }

    @Test("a key on the clip merges over its style's leaf by leaf, and false turns one off")
    func mergesClipKeyOverStyle() throws {
        // When
        let shape = try appearance(#"""
            { "kind": "rect", "area": [0, 0, 10, 10], "style": "outline", "stroke": { "width": 2 }, "fill": false,
              "shadow": { "radius": 4 }, "radius": 0, "outset": 0 }
            """#)

        // Then
        #expect(shape.stroke.stroke() == PathStroke(width: 1, paint: .color(Color(written: "#ED2929")), join: .round, cap: .butt, start: .none, end: .arrow))
        #expect(shape.fill == .off)
        #expect(shape.shadow.shadow() == DropShadow(radius: 2, offset: Point(x: 0, y: 4), color: Color(written: "#00000080")))
        #expect(shape.radius == .corners(0))
        #expect(shape.geometry == .area(outset: 0, anchor: nil))
    }

    @Test(
        "a closed path, a rect and an ellipse take a stroke inside or outside their outline, and a stroke is centred where no layer gives its align",
        arguments: [
            (#"{ "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "closed": true, "stroke": { "width": 2, "align": "inside" } }"#, StrokeAlign.inside),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "style": "pointer", "stroke": { "align": "outside" } }"#, .outside),
            (#"{ "kind": "ellipse", "area": [0, 0, 10, 10], "stroke": { "width": 2 } }"#, .center)
        ]
    )
    func takesAlign(
        clip: String,
        align: StrokeAlign
    ) throws {
        // When
        let shape = try appearance(clip)

        // Then
        #expect(shape.stroke.stroke()?.align == align)
    }

    @Test("a stroke colour over a style whose stroke a stronger theme turns off stops, naming the clip and that theme")
    func refusesPartialStrokeOverOff() throws {
        // Given
        let document = ##"""
            { "kind": "sequence", "format": { "size": [960, 540] },
              "theme": { "shapes": { "bar": { "stroke": false, "fill": "#FFFFFF" } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ],
              "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "style": "bar", "stroke": { "color": "#FF0000" }, "at": [0, 1] } ] }
            """##

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(document) }
        #expect(error.map { "\($0)" } == #"clips[0].stroke (rect): missing key "width", which the clip does not write and its theme turns off (theme.shapes.bar.stroke)"#)
    }

    @Test("a stroke colour on a shape without a style stands alone and stops without a width")
    func refusesPartialStrokeWithoutStyle() throws {
        // When, Then
        let error = #expect(throws: (any Error).self) {
            try plan(document(##"{ "kind": "rect", "area": [0, 0, 10, 10], "stroke": { "color": "#FF0000" } }"##))
        }
        #expect(error.map { "\($0)" } == #"clips[0].stroke (rect): missing key "width", which the clip does not write and no theme layer gives"#)
    }

    @Test("a shape without a style takes nothing from the theme but colour names, and its stroke the stroke defaults")
    func takesOnlyColourNamesWithoutStyle() throws {
        // When
        let shape = try appearance(#"{ "kind": "ellipse", "area": [0, 0, 10, 10], "stroke": { "width": 4 }, "fill": "brand" }"#)

        // Then
        #expect(shape == ShapeAppearance(
            kind: .ellipse,
            geometry: .area(outset: .off, anchor: nil),
            radius: .off,
            trim: .value(.whole),
            fill: .fill(Color(written: "#123456")),
            stroke: .stroke(PathStroke(width: 2, paint: .color(MergedTheme.base.color("accent")), join: .round, cap: .butt, start: .none, end: .none)),
            shadow: .off
        ))
    }

    @Test("a rect by its width and height is a box as written, placed as a media clip's box, whatever its outset")
    func placesBoxShape() throws {
        // When
        let plan = try plan(document(#"{ "kind": "rect", "width": 200, "height": 100, "outset": 10, "placement": "bottom-right", "fill": "accent" }"#))

        // Then
        // The outset of 5 grows only the outline, so the box of 200 by 100 is inset from the bottom right by the
        // placement padding.
        let padding = 96 * 0.5
        #expect(plan.clips[0].appearance.shape?.geometry == .box(width: .value(200), height: .value(100), outset: 5))
        #expect(plan.clips[0].box == ClipBox(
            size: Size(width: 200, height: 100),
            position: .value(Point(x: 960 - padding, y: 540 - padding)),
            anchor: Point(x: 200, y: 100),
            placement: BoxPlacement(name: "bottom-right", padding: padding, edge: padding)
        ))
    }

    @Test("a rect by its width and height and a rect by its area, with the same anchor, position and outset, put the top left of the box as written at the position")
    func placesOutsetBoxAndAreaAlike() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [960, 540] }, "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [
              { "kind": "rect", "width": 200, "height": 100, "anchor": "top-left", "position": [300, 200], "outset": 10,
                "fill": "accent", "at": [0, 1] },
              { "kind": "rect", "area": [0, 0, 200, 100], "anchor": "top-left", "position": [300, 200], "outset": 10,
                "fill": "accent", "at": [0, 1] } ] }
            """#

        // When
        let list = Evaluator().displayList(of: try ResolvedSequence(plan: plan(document), hashes: FileHashTable()), at: 0.5)

        // Then
        // The outset of 5 output pixels grows each drawn outline out from the box as written.
        let drawn = list.items.compactMap { item -> Rectangle? in
            guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else { return nil }

            return Rectangle(bounding: item.transform.apply(toCornersOf: rectangle))
        }
        #expect(drawn.count == 2)
        for rectangle in drawn {
            #expect(isClose(rectangle, Rectangle(x: 295, y: 195, width: 210, height: 110)), "a rect is drawn at \(rectangle)")
        }
    }

    @Test("a title parented to a rect by its width and height with an outset sits in the pixels of the box as written")
    func placesChildInBoxAsWritten() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [960, 540] }, "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [
              { "id": "card", "kind": "rect", "width": 200, "height": 100, "anchor": "top-left", "position": [300, 200],
                "outset": 10, "fill": "accent", "at": [0, 1] },
              { "kind": "title", "text": "a", "style": "title", "parent": "card", "anchor": "top-left", "position": [0, 0], "at": [0, 1] } ] }
            """#

        // When
        let list = Evaluator().displayList(of: try ResolvedSequence(plan: plan(document), hashes: FileHashTable()), at: 0.5)

        // Then
        // The title's box has its top left at the card's box's origin, the top left of the box as written.
        let title = try #require(list.items.first { item in
            guard case .glyphs = item.content else { return false }

            return true
        })
        let origin = title.transform.apply(to: Point(x: 0, y: 0))
        #expect(isClose(origin, Point(x: 300, y: 200)), "the title's box is at \(origin)")
    }

    @Test("an ellipse by its width and height turns about its anchor point, which its position puts where it names")
    func placesBoxShapeByPosition() throws {
        // When
        let plan = try plan(document(#"{ "kind": "ellipse", "width": 200, "height": 100, "anchor": "top-left", "position": [300, 200], "fill": "accent" }"#))

        // Then
        #expect(plan.clips[0].box == ClipBox(
            size: Size(width: 200, height: 100),
            position: .value(Point(x: 300, y: 200)),
            anchor: Point(x: 0, y: 0)
        ))
    }

    @Test("a shape placed by its area writes its area as written and its outset in output pixels, and its anchor a point of its area before the outset")
    func writesGeometryShape() throws {
        // When
        let shape = try resolvedShape(#"{ "kind": "rect", "area": [100, 100, 200, 100], "outset": 20, "anchor": "bottom-right", "position": [500, 300], "fill": "accent" }"#)

        // Then
        #expect(shape.geometry == .area(
            .keyframes([Keyframe(at: 0, value: .rectangle(Rectangle(x: 100, y: 100, width: 200, height: 100)))]),
            outset: 10,
            placement: GeometryPlacement(
                position: [Keyframe(at: 0, value: Point(x: 500, y: 300))],
                anchor: Point(x: 300, y: 200)
            )
        ))
    }

    @Test("a path's points are found as positions are, a named point of an area at that point of the area")
    func findsPathPoints() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "connected": [
                { "kind": "rect", "area": [100, 100, 200, 40], "parent": "screen", "fill": "accent" },
                { "kind": "path", "parent": "screen", "points": [[10, 20], { "area": [100, 100, 200, 40], "point": "left" }],
                  "closed": true, "stroke": { "width": 4, "end": "frames/arrow" } } ] } ] }
            """#

        // When
        let clips = try ResolvedSequence(plan: plan(document), hashes: FileHashTable()).clips

        // Then
        guard case let .picture(.shape(rect), _) = clips[0].content, case let .picture(.shape(path), _) = clips[1].content else {
            Issue.record("both clips are shapes")
            return
        }
        guard case let .area(area, _, _) = rect.geometry, case let .points(points, isClosed, placement) = path.geometry else {
            Issue.record("the rect is placed by its area and the path by its points")
            return
        }
        let total = try #require(area.values.first?.fixed)
        #expect(points.map(\.vertex.values) == [[.point(Point(x: 10, y: 20))], [.point(total.point(named: "left"))]])
        #expect(isClosed)
        #expect(placement.anchor == nil)
        #expect(clips[1].box == nil)
    }

    // MARK: - Private
    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        isClose(Point(x: rectangle.x, y: rectangle.y), Point(x: other.x, y: other.y))
            && isClose(Point(x: rectangle.maxX, y: rectangle.maxY), Point(x: other.maxX, y: other.maxY))
    }

    private func isClose(
        _ point: Point,
        _ other: Point
    ) -> Bool {
        abs(point.x - other.x) < 1e-6 && abs(point.y - other.y) < 1e-6
    }

    private func document(_ clip: String) -> String {
        #"""
        { "kind": "sequence", "format": { "size": [960, 540] }, "theme": \#(Self.theme),
          "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [ \#(clip.dropLast(2)), "at": [0, 1] } ] }
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
        guard case let .picture(.shape(shape), _) = clips.first?.content else {
            Issue.record("the clip is a shape")
            return ResolvedShape(area: [], fill: nil)
        }

        return shape
    }
}
