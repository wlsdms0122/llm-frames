//
//  ShapeKeyframeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Shapes are sequence clips over `/abs/screen.mp4` in a 960 by 540 frame, so theme lengths are half their written
// size, and each is checked by the key tables before it is planned. The theme holds the shape style `bar`, a stroke 8
// wide in `#ED2929` with a shadow 10 wide, and `dashed`, a stroke 4 wide dashed `[10, 5]`.
@Suite("Shape keyframe Tests")
struct ShapeKeyframeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a keyframe that writes only a stroke's colour moves it and keeps the style's width, join and cap")
    func movesStrokeColour() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "bar",
              "keyframes": [ { "at": 0, "stroke": { "color": "#000000" } }, { "at": 1, "stroke": { "color": "#FFFFFF" } } ] }
            """##)

        // Then
        #expect(shape.stroke.stroke(at: 0.5) == PathStroke(
            width: 4,
            color: Color(written: "#808080"),
            join: .round,
            cap: .butt,
            start: .none,
            end: .none
        ))
    }

    @Test("a stroke drawn on from width 0 to null ends on the style's width and follows a theme that changes it")
    func drawsStrokeOnToStyleWidth() throws {
        // Given
        let clip = ##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "bar",
              "keyframes": [ { "at": 0, "stroke": { "width": 0 } }, { "at": 1, "stroke": { "width": null } } ] }
            """##

        // When
        let shape = try resolvedShape(clip)
        let wider = try resolvedShape(clip, width: 20)

        // Then
        #expect(shape.stroke.stroke(at: 0) == nil)
        #expect(shape.stroke.stroke(at: 0.5)?.width == 2)
        #expect(shape.stroke.stroke(at: 1)?.width == 4)
        #expect(wider.stroke.stroke(at: 1)?.width == 10)
    }

    @Test("a stroke width written only in keyframes over no style is given, and draws")
    func takesKeyframedRequiredLeaf() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10],
              "keyframes": [ { "at": 0, "stroke": { "width": 2 } }, { "at": 1, "stroke": { "width": 6 } } ] }
            """##)

        // Then
        #expect(shape.stroke.stroke(at: 0.5)?.width == 2)
        #expect(shape.stroke.stroke(at: 0.5)?.color == MergedTheme.base.color("accent"))
    }

    @Test("fill colours interpolate per channel and a static fill colour stays under keyframes of another key")
    func movesFillColour() throws {
        // When
        let moved = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10],
              "keyframes": [ { "at": 0, "fill": "#FF0000" }, { "at": 1, "fill": "#0000FF" } ] }
            """##)

        // Then
        #expect(moved.fill.fillColor(at: 0.5) == Color(written: "#800080"))
    }

    @Test("shadow true in a keyframe is the merged shadow, so a shadow moves from a written radius to the style's")
    func movesShadowToLook() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "bar",
              "keyframes": [ { "at": 0, "shadow": { "radius": 0 } }, { "at": 1, "shadow": true } ] }
            """##)

        // Then
        #expect(shape.shadow.shadow(at: 0)?.radius == 0)
        #expect(shape.shadow.shadow(at: 1)?.radius == 5)
        #expect(shape.shadow.shadow(at: 1)?.offset == Point(x: 0, y: 4))
    }

    @Test("shadow true on a shape over a style shadow keeps the style's radius")
    func keepsStyleShadowRadius() throws {
        // When
        let shape = try resolvedShape(#"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "bar", "shadow": true }"#)

        // Then
        #expect(shape.shadow.shadow()?.radius == 5)
        #expect(shape.shadow.shadow()?.color == Color(written: "#00000080"))
    }

    @Test("a radius and an outset move between keyframes, and a radius null is the style's")
    func movesRadiusAndOutset() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "bar",
              "keyframes": [ { "at": 0, "radius": 0, "outset": 0 }, { "at": 1, "radius": null, "outset": 8 } ] }
            """##)

        // Then
        guard case let .area(_, outset, _) = shape.geometry else {
            Issue.record("the rect is placed by its area")
            return
        }
        #expect(shape.radius.number(at: 0.5) == 3)
        #expect(outset.number(at: 0.5) == 2)
    }

    @Test("an overshooting ease is clamped where the stroke width is sampled, so it draws no stroke below 0")
    func clampsSampledWidth() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "fill": "accent",
              "keyframes": [ { "at": 0, "stroke": { "width": 8 }, "ease": "back-out" }, { "at": 1, "stroke": { "width": 0 } } ] }
            """##)

        // Then
        let samples = stride(from: 0.0, through: 1, by: 0.05).map { shape.stroke.stroke(at: $0)?.width ?? 0 }
        #expect(samples.allSatisfy { $0 >= 0 })
        #expect(shape.stroke.stroke(at: 0.9) == nil)
    }

    @Test(
        "a keyframe of a static leaf or of a value off, null for an object, and a leaf written statically and in every keyframe stop, a keyframe's value naming the keyframe",
        arguments: [
            (
                #"{ "at": 0, "stroke": { "cap": "round" } }, { "at": 0.5, "stroke": { "width": 2 } }"#,
                #"clips[0].keyframes[0].stroke.cap (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"#
            ),
            (
                ##"{ "at": 0, "fill": false }, { "at": 1, "fill": "#FFFFFF" }"##,
                #"clips[0].keyframes[0].fill (keyframe): false or "none" turns a value off and is written on the clip, not in a keyframe"#
            ),
            (
                #"{ "at": 0, "stroke": null }, { "at": 1, "stroke": { "width": 2 } }"#,
                #"clips[0].keyframes[0].stroke (keyframe): null stands for a leaf, not for an object or a list"#
            ),
            (
                #"{ "at": 0, "shadow": { "radius": 2 } }, { "at": 1, "shadow": { "radius": 4 } }"#,
                #"clips[0].shadow.radius: written as a static value and in every keyframe that writes it, so the static value never shows"#
            ),
            (
                #"{ "at": 0, "stroke": { "width": 0 } }"#,
                #"clips[0].keyframes[0].stroke.width: 0.0 is outside the values this leaf takes"#
            ),
            (
                ##"{ "at": 0, "fill": "ink" }, { "at": 1, "fill": "#FFFFFF" }"##,
                #"clips[0].keyframes[0].fill (rect): colour "ink" is not in colors"#
            )
        ]
    )
    func refusesKeyframe(
        keyframes: String,
        message: String
    ) throws {
        // Given
        let clip = #"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "bar", "shadow": { "radius": 1 },
              "keyframes": [ \#(keyframes) ] }
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try resolvedShape(clip) }
        #expect(error.map { "\($0)" } == message)
    }

    @Test("dash lengths and the dash offset are theme lengths, scaled to output pixels")
    func scalesDash() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "dash": [8, 4, 2], "dashOffset": 6 } }
            """##)

        // Then
        let stroke = try #require(shape.stroke.stroke())
        #expect(stroke.dash == [4, 2, 1, 4, 2, 1])
        #expect(stroke.dashOffset == 3)
    }

    @Test("a static dash with a keyframed dash offset marches the style's dashes along the outline")
    func marchesDashes() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "dashed",
              "keyframes": [ { "at": 0, "stroke": { "dashOffset": 0 } }, { "at": 1, "stroke": { "dashOffset": 100 } } ] }
            """##)

        // Then
        #expect(shape.stroke.stroke(at: 0.5)?.dash == [5, 2.5])
        #expect(shape.stroke.stroke(at: 0.5)?.dashOffset == 25)
    }

    @Test("a clip's dash of zeros over its style's dashes stops, as the merged dash holds only zeros")
    func refusesMergedZeroDash() throws {
        // Given
        let clip = #"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "dashed", "stroke": { "dash": [0, 0] } }"#

        // When, Then
        #expect(throws: (any Error).self) { try resolvedShape(clip) }
    }

    @Test("a dash an overshooting ease carries to all zeros draws the stroke whole at that instant")
    func drawsSampledZeroDashWhole() throws {
        // When
        // back-out peaks at about 1.1 near 0.58, carrying 20 towards 1 past 0.
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2 },
              "keyframes": [ { "at": 0, "stroke": { "dash": [20, 20] }, "ease": "back-out" }, { "at": 1, "stroke": { "dash": [1, 1] } } ] }
            """##)

        // Then
        #expect(shape.stroke.stroke(at: 0.58)?.dash == nil)
        #expect(shape.stroke.stroke(at: 0.58)?.width == 1)
        #expect(shape.stroke.stroke(at: 1)?.dash == [0.5, 0.5])
    }

    @Test("a shape's timed values read back from its resolved entry as they were written")
    func roundTripsTimedValues() throws {
        // Given
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "bar", "fill": "#FFFFFF",
              "keyframes": [ { "at": 0, "stroke": { "width": 0 }, "shadow": { "color": "#000000" }, "outset": 0, "ease": "ease-in" },
                             { "at": 1, "stroke": { "width": null }, "shadow": { "color": "#FF000080" }, "outset": 2 } ] }
            """##)
        let writer = ResolvedValueWriter()
        let reader = ResolvedValueReader()
        let place = Place.root.appending(key: "clips")

        // When
        let read = { (value: TimedValue, structure: ValueStructure) in
            try reader.timed(PlacedJSONValue(writer.timed(value), place: place, kind: "rect"), as: structure)
        }

        // Then
        #expect(try read(shape.fill, LookStructureTable.fill) == shape.fill)
        #expect(try read(shape.stroke, LookStructureTable.stroke) == shape.stroke)
        #expect(try read(shape.shadow, LookStructureTable.shadow) == shape.shadow)
        #expect(try read(shape.radius, LookStructureTable.length) == shape.radius)
    }

    // MARK: - Private
    // `width` is the width of the style's stroke.
    private func resolvedShape(
        _ clip: String,
        width: Double = 8
    ) throws -> ResolvedShape {
        let document = #"""
            { "kind": "sequence", "format": { "size": [960, 540] },
              "theme": { "colors": { "brand": "#123456" },
                         "shadow": { "radius": 20, "offset": [0, 8], "color": "#00000080" },
                         "shapes": { "bar": { "stroke": { "width": \#(width), "color": "#ED2929" }, "radius": 12, "shadow": { "radius": 10 } },
                                     "dashed": { "stroke": { "width": 4, "dash": [10, 5] } } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip.dropLast(1)), "at": [0, 1] } ] }
            """#
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document))
        let clips = try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips
        guard case let .shape(shape) = clips.first?.content else {
            Issue.record("the clip is a shape")
            return ResolvedShape(area: [], fill: nil)
        }

        return shape
    }
}
