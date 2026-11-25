//
//  ShapeKeyframeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames
import FramesTestMedia

// Shapes are sequence clips over `/abs/screen.mp4` in a 960 by 540 frame, so theme lengths are half their written
// size, and each is checked by the key tables before it is planned. The theme holds the colour `brand` `#123456` and
// the shape styles `bar`, a stroke 8 wide in `#ED2929` with a shadow 10 wide, `dashed`, a stroke 4 wide dashed
// `[10, 5]`, `glow`, a radial fill about `[0.25, 0.5]` from `brand` to `#00000000` and a stroke 2 wide with a linear
// gradient from `[0.25, 0]` to `[1, 0.5]`, red to blue, `ramp`, a linear fill from `[0, 0]` to `[1, 0]` through
// red, green at 0.5 and blue, and `pointer`, a stroke 4 wide ending in a diamond at scale 2.
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
            paint: .color(Color(written: "color(srgb 0.5 0.5 0.5)")),
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
        #expect(shape.stroke.stroke(at: 0.5)?.paint == .color(MergedTheme.base.color("accent")))
    }

    @Test("fill colours interpolate per channel and a static fill colour stays under keyframes of another key")
    func movesFillColour() throws {
        // When
        let moved = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10],
              "keyframes": [ { "at": 0, "fill": "#FF0000" }, { "at": 1, "fill": "#0000FF" } ] }
            """##)

        // Then
        #expect(moved.fill.fill(at: 0.5) == .color(Color(written: "color(srgb 0.5 0 0.5)")))
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
        #expect(shape.radius.cornerRadii(at: 0.5) == 3)
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
                #"clips[0].keyframes[0].stroke.cap (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe"#
            ),
            (
                #"{ "at": 0, "stroke": { "end": "frames/circle" } }, { "at": 0.5, "stroke": { "width": 2 } }"#,
                #"clips[0].keyframes[0].stroke.end.preset (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe"#
            ),
            (
                #"{ "at": 0, "stroke": { "end": { "scale": 0 } } }"#,
                #"clips[0].keyframes[0].stroke.end.scale: 0 is not above 0"#
            ),
            (
                #"{ "at": 0, "stroke": { "align": "inside" } }, { "at": 0.5, "stroke": { "width": 2 } }"#,
                #"clips[0].keyframes[0].stroke.align (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe"#
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
                #"clips[0].keyframes[0].stroke.width: 0 is not above 0"#
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

    @Test("an end written as a name names its preset alone, keeping its style's scale, and a bare stroke's end is scale 1")
    func namesEndPreset() throws {
        // When
        let named = try resolvedShape(#"{ "shape": "path", "points": [[0, 0], [100, 0]], "style": "pointer", "stroke": { "end": "frames/circle" } }"#)
        let bare = try resolvedShape(#"{ "shape": "path", "points": [[0, 0], [100, 0]], "stroke": { "width": 4, "start": "frames/bar" } }"#)

        // Then
        #expect(named.stroke.stroke(at: 0)?.start == StrokeEnd.none)
        #expect(named.stroke.stroke(at: 0)?.end == StrokeEnd(head: .circle, scale: 2))
        #expect(bare.stroke.stroke(at: 0)?.start == StrokeEnd(head: .bar, scale: 1))
        #expect(bare.stroke.stroke(at: 0)?.end == StrokeEnd.none)
    }

    @Test("an end's scale moves between keyframes from 0, as a stroke's width does, its preset the style's")
    func movesEndScale() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "path", "points": [[0, 0], [100, 0]], "style": "pointer",
              "keyframes": [ { "at": 0, "stroke": { "end": { "scale": 0 } } }, { "at": 1, "stroke": { "end": { "scale": null } } } ] }
            """##)

        // Then
        #expect(shape.stroke.stroke(at: 0)?.end == StrokeEnd(head: .diamond, scale: 0))
        #expect(shape.stroke.stroke(at: 0.5)?.end == StrokeEnd(head: .diamond, scale: 1))
        #expect(shape.stroke.stroke(at: 1)?.end == StrokeEnd(head: .diamond, scale: 2))
    }

    @Test("a gradient's leaf written statically and in every keyframe stops, naming the leaf under its gradient")
    func refusesStaticGradientLeaf() throws {
        // Given
        let clip = ##"""
            { "shape": "rect", "area": [0, 0, 10, 10],
              "fill": { "radial": { "center": [0.5, 0.5], "radius": 0.5, "stops": [[0, "#FF0000"], [1, "#0000FF"]] } },
              "keyframes": [ { "at": 0, "fill": { "radial": { "center": [0.2, 0.2] } } },
                             { "at": 1, "fill": { "radial": { "center": [0.8, 0.8] } } } ] }
            """##

        // When, Then
        let error = #expect(throws: (any Error).self) { try resolvedShape(clip) }
        #expect(error.map { "\($0)" } == "clips[0].fill.radial.center: written as a static value and in every keyframe that writes it, so the static value never shows")
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

    @Test("a keyframe dash whose lengths over the merged dash are all 0 stops at that keyframe, as a static one does")
    func refusesKeyframeZeroDash() throws {
        // Given
        let clip = ##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "dash": [3, 0] },
              "keyframes": [ { "at": 0, "stroke": { "dash": [null, null] } }, { "at": 1, "stroke": { "dash": [0, null] } } ] }
            """##

        // When, Then
        let error = #expect(throws: (any Error).self) { try resolvedShape(clip) }
        #expect(error.map { "\($0)" } == "clips[0].keyframes[1].stroke.dash: lengths that are all 0, which draw no dash")
    }

    @Test("keyframe dashes are each checked over the merged dash, not over the keyframes before them")
    func takesKeyframeDashOverMerged() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "dashed",
              "keyframes": [ { "at": 0, "stroke": { "dash": [0, 5] } }, { "at": 1, "stroke": { "dash": [null, 0] } } ] }
            """##)

        // Then
        #expect(shape.stroke.stroke(at: 0)?.dash == [0, 2.5])
        #expect(shape.stroke.stroke(at: 1)?.dash == [5, 0])
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
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "bar", "fill": "#FFFFFF", "stroke": { "align": "outside" },
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
        #expect(try read(shape.radius, LookStructureTable.radius) == shape.radius)
    }

    @Test("a gradient's points are fractions of the shape's box and a radial radius of 1 reaches its farthest corner, wide or tall")
    func laysGradientOverBox() throws {
        // When
        let shape = try resolvedShape(#"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "glow" }"#)

        // Then
        let stops = [GradientStop(offset: 0, color: Color(written: "#123456")), GradientStop(offset: 1, color: Color(written: "#00000000"))]
        #expect(shape.fill.fill(box: Rectangle(x: 0, y: 0, width: 200, height: 100)) == .gradient(Gradient(
            shape: .radial(center: Point(x: 50, y: 50), radius: (150.0 * 150 + 50 * 50).squareRoot()),
            stops: stops
        )))
        #expect(shape.fill.fill(box: Rectangle(x: 0, y: 0, width: 100, height: 200)) == .gradient(Gradient(
            shape: .radial(center: Point(x: 25, y: 100), radius: 125),
            stops: stops
        )))
        #expect(shape.stroke.stroke(box: Rectangle(x: 10, y: 20, width: 200, height: 100))?.paint == .gradient(Gradient(
            shape: .linear(from: Point(x: 60, y: 20), to: Point(x: 210, y: 70)),
            stops: [GradientStop(offset: 0, color: Color(written: "#FF0000")), GradientStop(offset: 1, color: Color(written: "#0000FF"))]
        )))
    }

    @Test("a radial radius is a fraction of the distance to the farthest corner, and a clip moves one point of its style's gradient")
    func takesRadiusAndPartialGradient() throws {
        // When
        let sized = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10],
              "fill": { "radial": { "center": [0, 0], "radius": 0.5, "stops": [[0, "#000000"], [1, "#FFFFFF"]] } } }
            """##)
        let moved = try resolvedShape(#"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "glow", "fill": { "radial": { "center": [1, 1] } } }"#)

        // Then
        let box = Rectangle(x: 0, y: 0, width: 4, height: 3)
        #expect(gradient(sized.fill.fill(box: box))?.shape == .radial(center: Point(x: 0, y: 0), radius: 2.5))
        #expect(gradient(moved.fill.fill(box: box))?.shape == .radial(center: Point(x: 4, y: 3), radius: 5))
        #expect(gradient(moved.fill.fill(box: box))?.stops.map(\.color) == [Color(written: "#123456"), Color(written: "#00000000")])
    }

    @Test(
        "a stop naming a colour the theme lacks, a keyframe of another kind, and a null stop leaf in keyframes giving another number of stops than the style's, whose list replaces the style's, stop",
        arguments: [
            ##""fill": { "linear": { "from": [0, 0], "to": [1, 0], "stops": [[0, "ink"], [1, "#FFFFFF"]] } }"##,
            ##""style": "ramp", "keyframes": [ { "at": 0, "fill": { "linear": { "stops": [[0, null], [1, null]] } } }, { "at": 1, "fill": { "linear": { "stops": [[0.5, null], [1, null]] } } } ]"##,
            ##""style": "ramp", "keyframes": [ { "at": 0, "fill": { "radial": { "center": [0, 0] } } }, { "at": 1, "fill": { "radial": { "center": [1, 1] } } } ]"##
        ]
    )
    func refusesGradient(written: String) throws {
        // Given
        let clip = #"{ "shape": "rect", "area": [0, 0, 10, 10], \#(written) }"#

        // When, Then
        #expect(throws: (any Error).self) { try resolvedShape(clip) }
    }

    @Test("a gradient's points, offsets and colours move between keyframes over the style's, a null stop leaf being the clip's static one")
    func movesGradient() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "glow",
              "fill": { "radial": { "stops": [[0, "#000000"], [1, "#00000000"]] } },
              "keyframes": [ { "at": 0, "fill": { "radial": { "center": [0, 0], "stops": [[null, null], [0.5, null]] } } },
                             { "at": 1, "fill": { "radial": { "center": [1, 1], "stops": [[null, "#FFFFFF"], [null, null]] } } } ] }
            """##)

        // Then
        let moved = try #require(gradient(shape.fill.fill(at: 0.5, box: Rectangle(x: 0, y: 0, width: 200, height: 100))))
        #expect(moved.shape == .radial(center: Point(x: 100, y: 50), radius: (100.0 * 100 + 50 * 50).squareRoot()))
        #expect(moved.stops == [
            GradientStop(offset: 0, color: Color(written: "color(srgb 0.5 0.5 0.5)")),
            GradientStop(offset: 0.75, color: Color(written: "#00000000"))
        ])
    }

    @Test("keyframes giving as many stops as the style's move one stop and keep the other, a null leaf being the style's")
    func movesOneStyleStop() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "glow",
              "keyframes": [ { "at": 0, "fill": { "radial": { "stops": [[null, null], [0.5, "#000000"]] } } },
                             { "at": 1, "fill": { "radial": { "stops": [[null, null], [1, "#FFFFFF"]] } } } ] }
            """##)

        // Then
        let moved = try #require(gradient(shape.fill.fill(at: 0.5, box: Rectangle(x: 0, y: 0, width: 200, height: 100))))
        #expect(moved.stops == [
            GradientStop(offset: 0, color: Color(written: "#123456")),
            GradientStop(offset: 0.75, color: Color(written: "color(srgb 0.5 0.5 0.5)"))
        ])
    }

    @Test("keyframes giving as many dash lengths as the style's move one and keep the other, a null leaf being the style's")
    func movesOneStyleDash() throws {
        // When
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "dashed",
              "keyframes": [ { "at": 0, "stroke": { "dash": [null, 5] } }, { "at": 1, "stroke": { "dash": [null, 25] } } ] }
            """##)

        // Then
        #expect(shape.stroke.stroke(at: 0)?.dash == [5, 2.5])
        #expect(shape.stroke.stroke(at: 0.5)?.dash == [5, 7.5])
        #expect(shape.stroke.stroke(at: 1)?.dash == [5, 12.5])
    }

    @Test("keyframes giving another number of dash lengths than the style's replace its dash, so a null leaf there stops")
    func refusesNullOverOtherDash() throws {
        // Given
        let clip = ##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "dashed",
              "keyframes": [ { "at": 0, "stroke": { "dash": [null, 5, 2] } }, { "at": 1, "stroke": { "dash": [4, 5, 2] } } ] }
            """##

        // When, Then
        let error = #expect(throws: (any Error).self) { try resolvedShape(clip) }
        #expect(error.map { "\($0)" } == "clips[0].keyframes[0].stroke.dash[0] (keyframe): null points at the merged value, which holds none here")
    }

    @Test("an overshooting ease clamps each sampled offset to 0 to 1 and raises it to the one before it")
    func ordersSampledOffsets() throws {
        // When
        // back-out peaks at about 1.1 near 0.58, carrying the first offset to about 0.99 past the second's 0.95 and the
        // third to about 1.05.
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "ramp",
              "keyframes": [ { "at": 0, "fill": { "linear": { "stops": [[0, "#FF0000"], [0.95, "#00FF00"], [0.5, "#0000FF"]] } }, "ease": "back-out" },
                             { "at": 1, "fill": { "linear": { "stops": [[0.9, "#FF0000"], [0.95, "#00FF00"], [1, "#0000FF"]] } } } ] }
            """##)

        // Then
        let start = try #require(gradient(shape.fill.fill(at: 0))).stops.map(\.offset)
        let peak = try #require(gradient(shape.fill.fill(at: 0.58))).stops.map(\.offset)
        #expect(start.dropFirst() == [0.95, 0.95])
        #expect(peak[0] > 0.95)
        #expect(peak == [peak[0], peak[0], 1])
    }

    @Test("a colour fill, static or only in keyframes, and keyframes of a stroke's colour replace a style's gradient")
    func replacesStyleGradientWithColor() throws {
        // When
        let painted = try resolvedShape(##"{ "shape": "rect", "area": [0, 0, 10, 10], "style": "glow", "fill": "#FF0000" }"##)
        let keyed = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "glow",
              "keyframes": [ { "at": 0, "fill": "#000000", "stroke": { "color": "#000000" } },
                             { "at": 1, "fill": "#FFFFFF", "stroke": { "color": "#FFFFFF" } } ] }
            """##)

        // Then
        #expect(painted.fill.fill() == .color(Color(written: "#FF0000")))
        #expect(keyed.fill.fill(at: 0.5) == .color(Color(written: "color(srgb 0.5 0.5 0.5)")))
        #expect(keyed.stroke.stroke(at: 0.5)?.paint == .color(Color(written: "color(srgb 0.5 0.5 0.5)")))
        #expect(keyed.stroke.stroke(at: 0.5)?.width == 1)
    }

    @Test("a gradient fill and a stroke gradient, keyframed, read back from the resolved entry as they were written")
    func roundTripsGradients() throws {
        // Given
        let shape = try resolvedShape(##"""
            { "shape": "rect", "area": [0, 0, 10, 10], "style": "glow",
              "fill": { "radial": { "stops": [[0, "#000000"], [1, "#FFFFFF"]] } },
              "keyframes": [ { "at": 0, "fill": { "radial": { "radius": 0.5, "stops": [[0.2, null], [null, "#FF0000"]] } } },
                             { "at": 1, "fill": { "radial": { "radius": 1, "stops": [[null, null], [null, null]] } } } ] }
            """##)
        let writer = ResolvedValueWriter()
        let reader = ResolvedValueReader()
        let place = Place.root.appending(key: "clips")

        // When
        let read = { (value: TimedValue, structure: ValueStructure) in
            try reader.timed(PlacedJSONValue(writer.timed(value), place: place, kind: "rect"), as: structure)
        }

        // Then
        #expect(gradient(shape.fill.fill(at: 0.5)) != nil)
        #expect(try read(shape.fill, LookStructureTable.fill) == shape.fill)
        #expect(try read(shape.stroke, LookStructureTable.stroke) == shape.stroke)
    }

    // MARK: - Private
    private func gradient(_ paint: Paint?) -> Gradient? {
        guard case let .gradient(gradient) = paint else { return nil }

        return gradient
    }

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
                                     "dashed": { "stroke": { "width": 4, "dash": [10, 5] } },
                                     "pointer": { "stroke": { "width": 4, "end": { "preset": "frames/diamond", "scale": 2 } } },
                                     "glow": { "fill": { "radial": { "center": [0.25, 0.5], "stops": [[0, "brand"], [1, "#00000000"]] } },
                                               "stroke": { "width": 2, "gradient": { "linear": { "from": [0.25, 0], "to": [1, 0.5],
                                                           "stops": [[0, "#FF0000"], [1, "#0000FF"]] } } } },
                                     "ramp": { "fill": { "linear": { "from": [0, 0], "to": [1, 0],
                                               "stops": [[0, "#FF0000"], [0.5, "#00FF00"], [1, "#0000FF"]] } } } } },
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
