//
//  PresetReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("PresetReader Tests")
struct PresetReaderTests {
    // MARK: - Property
    private let sut = PresetReader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("an animation preset reads its spans with each span's default ease")
    func readsAnimation() throws {
        // Given
        let data = Data(#"""
            { "description": "pops in",
              "entrance": { "seconds": 0.35, "revealFrom": "top", "keys": [ { "t": 0, "scale": 0.6, "opacity": 0 }, { "t": 1, "scale": 1 } ] },
              "loop":     { "period": 0.9, "keys": [ { "t": 0.5, "y": -0.05 } ] },
              "exit":     { "seconds": 0.15, "ease": "linear", "keys": [ { "t": 1, "opacity": 0 } ] } }
            """#.utf8)

        // When
        let preset = try sut.animation(from: data)

        // Then
        #expect(preset.description == "pops in")
        #expect(preset.entrance?.length == 0.35)
        #expect(preset.entrance?.span.ease == .easeOut)
        #expect(preset.entrance?.span.revealFrom == .top)
        #expect(preset.entrance?.span.keys.first == SpanKey(t: 0, values: [.scale: 0.6, .opacity: 0]))
        #expect(preset.loop?.length == 0.9)
        #expect(preset.loop?.span.ease == .easeInOut)
        #expect(preset.loop?.span.revealFrom == .left)
        #expect(preset.exit?.span.ease == .linear)
    }

    @Test("every animation span is optional")
    func readsEmptyAnimation() throws {
        // Given
        let value = try Fixture.json(#"{ "description": "no motion" }"#)

        // When
        let preset = try sut.animation(from: value)

        // Then
        #expect(preset.entrance == nil)
        #expect(preset.loop == nil)
        #expect(preset.exit == nil)
    }

    @Test(
        "an animation preset with a broken rule stops",
        arguments: [
            (#"{ "entrance": { "seconds": 1 } }"#, #"top level (animation): missing key "description""#),
            (#"{ "description": "x", "entrance": { "keys": [] } }"#, #"entrance (entrance): missing key "seconds""#),
            (#"{ "description": "x", "loop": { "seconds": 1 } }"#, #"loop (loop): unknown key "seconds". Allowed: period, ease, revealFrom, keys"#),
            (#"{ "description": "x", "exit": { "seconds": 1, "keys": [ { "t": 1, "blur": 1 } ] } }"#, #"exit.keys[0] (span key): unknown key "blur". Allowed: t, opacity, scale, x, y, rotation, reveal"#),
            (#"{ "description": "x", "exit": { "seconds": 1, "keys": [ { "opacity": 1 } ] } }"#, #"exit.keys[0] (span key): missing key "t""#),
            (#"{ "description": "x", "exit": { "seconds": 1, "keys": [ { "t": 1.5, "opacity": 1 } ] } }"#, "exit.keys[0] (span key): t is progress through the span and lies between 0 and 1, found 1.5"),
            (#"{ "description": "x", "entrance": { "seconds": 0 } }"#, "entrance.seconds (entrance): a span runs for more than 0 seconds, found 0"),
            (#"{ "description": "x", "entrance": { "seconds": 1, "revealFrom": "middle" } }"#, #"entrance.revealFrom (entrance): unknown value "middle". Allowed: left, right, top, bottom"#),
            (#"{ "description": "x", "intro": {} }"#, #"top level (animation): unknown key "intro". Allowed: description, params, entrance, loop, exit"#)
        ]
    )
    func refusesBrokenAnimation(
        text: String,
        message: String
    ) throws {
        // Given
        let value = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.animation(from: value) }
        #expect("\(error.map { "\($0)" } ?? "")" == message)
    }

    @Test("a transition preset reads its spans with the preset's ease as their default")
    func readsTransition() throws {
        // Given
        let value = try Fixture.json(##"""
            { "description": "pushes up",
              "seconds": 0.45, "ease": "ease-in-out", "over": "incoming", "audio": "constant-gain",
              "incoming": { "keys": [ { "t": 0, "y": 1 }, { "t": 1, "y": 0 } ] },
              "outgoing": { "ease": "linear", "keys": [ { "t": 0, "y": 0 }, { "t": 1, "y": -1 } ] },
              "cover":    { "color": "#FFFFFF", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
            """##)

        // When
        let preset = try sut.transition(from: value)

        // Then
        #expect(preset.seconds == 0.45)
        #expect(preset.over == .incoming)
        #expect(preset.audio == .constantGain)
        #expect(preset.incoming?.ease == .easeInOut)
        #expect(preset.outgoing?.ease == .linear)
        #expect(preset.cover?.source == .color("#FFFFFF"))
        #expect(preset.cover?.span.ease == .easeInOut)
        #expect(preset.cover?.span.keys.count == 3)
        #expect(preset.matte == nil)
    }

    @Test("a spring is taken as a transition's, a span's and a matte's ease")
    func readsSpringEases() throws {
        // Given
        let transition = try Fixture.json(#"""
            { "description": "x", "seconds": 1, "ease": { "kind": "spring", "bounce": 0.2 },
              "incoming": { "ease": { "kind": "spring", "bounce": -0.3 }, "keys": [ { "t": 0, "y": 1 }, { "t": 1, "y": 0 } ] },
              "matte": { "media": "/abs/m.png" } }
            """#)
        let animation = try Fixture.json(#"{ "description": "x", "entrance": { "seconds": 0.5, "ease": { "kind": "spring", "bounce": 0.5 } } }"#)

        // When
        let readTransition = try sut.transition(from: transition)
        let readAnimation = try sut.animation(from: animation)

        // Then
        #expect(readTransition.incoming?.ease == .spring(bounce: -0.3))
        #expect(readTransition.matte?.ease == .spring(bounce: 0.2))
        #expect(readAnimation.entrance?.span.ease == .spring(bounce: 0.5))
    }

    @Test("a matte transition reads its media, softness and invert, and without `audio` crossfades at constant power")
    func readsMatte() throws {
        // Given
        let value = try Fixture.json(#"{ "description": "luma wipe", "seconds": 1, "matte": { "media": "pack/gradient.png", "softness": 0.1, "invert": true } }"#)

        // When
        let preset = try sut.transition(from: value)

        // Then
        #expect(preset.over == .incoming)
        #expect(preset.audio == .constantPower)
        #expect(preset.matte == Matte(media: "pack/gradient.png", softness: 0.1, isInverted: true, ease: .linear))
    }

    @Test(
        "a transition preset with a broken rule stops",
        arguments: [
            (#"{ "description": "x", "seconds": 1, "incoming": { "seconds": 0.5, "keys": [] } }"#, #"incoming (incoming): unknown key "seconds". Allowed: ease, revealFrom, keys"#),
            (#"{ "description": "x", "seconds": 1, "outgoing": { "period": 0.5 } }"#, #"outgoing (outgoing): unknown key "period". Allowed: ease, revealFrom, keys"#),
            (#"{ "description": "x", "seconds": 1, "over": "outgoing", "matte": { "media": "/abs/m.png" } }"#, #"top level (transition): a matte reveals the incoming storyline picture, so it cannot play with "over": "outgoing""#),
            (#"{ "description": "x" }"#, #"top level (transition): missing key "seconds""#),
            (#"{ "description": "x", "seconds": 1, "cover": { "keys": [] } }"#, "cover (cover): needs one of color, media"),
            (##"{ "description": "x", "seconds": 1, "cover": { "color": "#000000", "media": "/abs/s.mov" } }"##, #"cover (cover): takes only one of "color", "media""#),
            (##"{ "description": "x", "seconds": 1, "cover": { "color": "#000000", "keys": [ { "t": 0, "scale": 2 } ] } }"##, #"cover.keys[0] (cover key): unknown key "scale". Allowed: t, opacity"#),
            (#"{ "description": "x", "seconds": 1, "matte": { "softness": 0.2 } }"#, #"matte (matte): missing key "media""#),
            (#"{ "description": "x", "seconds": 1, "over": "above" }"#, #"over (transition): unknown value "above". Allowed: incoming, outgoing"#),
            (#"{ "description": "x", "seconds": 1, "audio": "linear" }"#, #"audio (transition): unknown value "linear". Allowed: constant-power, constant-gain"#),
            (#"{ "description": "x", "seconds": 1, "ease": { "kind": "spring", "bounce": 1.5 } }"#, "ease.spring.bounce (spring): 1.5 is not above -1 and below 1"),
            (#"{ "description": "x", "seconds": 1, "audio": { "param": "curve" } }"#, "audio (transition): expected one of constant-power, constant-gain, found an object")
        ]
    )
    func refusesBrokenTransition(
        text: String,
        message: String
    ) throws {
        // Given
        let value = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.transition(from: value) }
        #expect("\(error.map { "\($0)" } ?? "")" == message)
    }

    @Test("a filter preset reads its chain of operations in order")
    func readsFilter() throws {
        // Given
        let value = try Fixture.json(##"""
            { "description": "faded warmth", "ops": [
              { "kind": "saturation", "amount": 0 }, { "kind": "contrast", "amount": 1.3 },
              { "kind": "levels", "input": [0.1, 0.9], "output": [0, 1] }, { "kind": "lut", "file": "pack/warm", "amount": 0.5 },
              { "kind": "bloom", "amount": 0.4, "radius": 12, "color": "#FFAA00" }, { "kind": "grain", "amount": 0.2, "size": 2 }
            ] }
            """##)

        // When
        let preset = try sut.filter(from: value)

        // Then
        #expect(preset.description == "faded warmth")
        #expect(preset.operations == [
            .saturation(amount: 0),
            .contrast(amount: 1.3),
            .levels(input: [0.1, 0.9], output: [0, 1]),
            .lut(file: "pack/warm", amount: 0.5),
            .bloom(amount: 0.4, radius: 12, color: "#FFAA00"),
            .grain(amount: 0.2, size: 2)
        ])
    }

    @Test("filter parameters at the ends of their ranges are kept")
    func acceptsRangeEnds() throws {
        // Given
        let value = try Fixture.json(#"""
            { "description": "x", "ops": [
              { "kind": "sepia", "amount": 0 }, { "kind": "lut", "file": "/abs/a.cube", "amount": 1 },
              { "kind": "levels", "input": [0, 1], "output": [0.2, 0.8] }, { "kind": "vignette", "amount": 0.5, "radius": 0 },
              { "kind": "grain", "amount": 1, "size": 0.5 }, { "kind": "pixelate", "size": 8 }
            ] }
            """#)

        // When
        let preset = try sut.filter(from: value)

        // Then
        #expect(preset.operations.count == 6)
    }

    @Test(
        "a filter preset with a broken rule stops",
        arguments: [
            (#"{ "description": "x", "ops": [ { "kind": "glow", "amount": 1 } ] }"#, #"ops[0].op (filter operation): unknown value "glow". Allowed: exposure, contrast, saturation, temperature, hue, sepia, levels, lut, blur, sharpen, bloom, vignette, displace, pixelate, grain"#),
            (#"{ "description": "x", "ops": [ { "amount": 1 } ] }"#, #"ops[0] (filter operation): missing key "op""#),
            (#"{ "description": "x", "ops": [ { "kind": "blur", "radius": 2, "amount": 1 } ] }"#, #"ops[0] (blur): unknown key "amount". Allowed: op, radius"#),
            (#"{ "description": "x", "ops": [ { "kind": "exposure" } ] }"#, #"ops[0] (exposure): missing key "ev""#),
            (#"{ "description": "x", "ops": [ { "kind": "levels", "input": [0, 1, 2], "output": [0, 1] } ] }"#, "ops[0].input (levels): expected a list of 2 numbers, found a list of 3"),
            (#"{ "description": "x" }"#, #"top level (filter): missing key "ops""#),
            (#"{ "description": "x", "ops": [ { "kind": "sepia", "amount": 1.5 } ] }"#, "ops[0].amount (sepia): 1.5 is not within 0 to 1"),
            (#"{ "description": "x", "ops": [ { "kind": "lut", "file": "pack/warm", "amount": -0.1 } ] }"#, "ops[0].amount (lut): -0.1 is not within 0 to 1"),
            (#"{ "description": "x", "ops": [ { "kind": "grain", "amount": 2, "size": 1 } ] }"#, "ops[0].amount (grain): 2 is not within 0 to 1"),
            (#"{ "description": "x", "ops": [ { "kind": "grain", "amount": 0.2, "size": 0 } ] }"#, "ops[0].size (grain): 0 is not above 0"),
            (#"{ "description": "x", "ops": [ { "kind": "levels", "input": [0, 1.2], "output": [0, 1] } ] }"#, "ops[0].input (levels): [0, 1.2] is not within 0 to 1 with black below white"),
            (#"{ "description": "x", "ops": [ { "kind": "levels", "input": [0, 1], "output": [0.9, 0.1] } ] }"#, "ops[0].output (levels): [0.9, 0.1] is not within 0 to 1 with black below white"),
            (#"{ "description": "x", "ops": [ { "kind": "levels", "input": [0.5, 0.5], "output": [0, 1] } ] }"#, "ops[0].input (levels): [0.5, 0.5] is not within 0 to 1 with black below white"),
            (#"{ "description": "x", "ops": [ { "kind": "contrast", "amount": 1 }, { "kind": "blur", "radius": -2 } ] }"#, "ops[1].radius (blur): -2 is not above 0"),
            (#"{ "description": "x", "ops": [ { "kind": "sharpen", "amount": 1, "radius": 0 } ] }"#, "ops[0].radius (sharpen): 0 is not above 0"),
            (#"{ "description": "x", "ops": [ { "kind": "bloom", "amount": 1, "radius": 0 } ] }"#, "ops[0].radius (bloom): 0 is not above 0"),
            (#"{ "description": "x", "ops": [ { "kind": "pixelate", "size": -1 } ] }"#, "ops[0].size (pixelate): -1 is not above 0"),
            (#"{ "description": "x", "ops": [ { "kind": "vignette", "amount": 0.5, "radius": 1.1 } ] }"#, "ops[0].radius (vignette): 1.1 is not within 0 to 1"),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "file": "/abs/ripple.png", "amount": 0 } ] }"#, "ops[0].amount (displace): 0 is not above 0"),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "file": "/abs/ripple.png", "amount": -4 } ] }"#, "ops[0].amount (displace): -4 is not above 0"),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "file": "/abs/ripple.png", "amount": 4, "offset": [1] } ] }"#, "ops[0].offset (displace): expected a list of 2 numbers, found a list of 1"),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "file": "/abs/ripple.png", "amount": 4, "offset": [1, 2, 3] } ] }"#, "ops[0].offset (displace): expected a list of 2 numbers, found a list of 3"),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "file": "/abs/ripple.png", "amount": 4, "offset": 1 } ] }"#, "ops[0].offset (displace): expected a list of 2 numbers, found 1"),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "file": "/abs/ripple.png", "amount": 4, "radius": 2 } ] }"#, #"ops[0] (displace): unknown key "radius". Allowed: op, file, amount, offset"#),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "amount": 4 } ] }"#, #"ops[0] (displace): missing key "file""#),
            (#"{ "description": "x", "ops": [ { "kind": "displace", "file": "/abs/ripple.png" } ] }"#, #"ops[0] (displace): missing key "amount""#)
        ]
    )
    func refusesBrokenFilter(
        text: String,
        message: String
    ) throws {
        // Given
        let value = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.filter(from: value) }
        #expect("\(error.map { "\($0)" } ?? "")" == message)
    }

    @Test("a displace op reads its map, its amount and its offset, which takes any real number and is [0, 0] where none is written")
    func readsDisplace() throws {
        // Given
        let value = try Fixture.json(#"""
            { "description": "x", "ops": [
              { "kind": "displace", "file": "pack/ripple.png", "amount": 12 },
              { "kind": "displace", "file": "/abs/ripple.png", "amount": 0.5, "offset": [-40, 2.5] }
            ] }
            """#)

        // When
        let preset = try sut.filter(from: value)

        // Then
        #expect(preset.operations == [
            .displace(file: "pack/ripple.png", amount: 12, offset: Point(x: 0, y: 0)),
            .displace(file: "/abs/ripple.png", amount: 0.5, offset: Point(x: -40, y: 2.5))
        ])
    }

    @Test("a displace op's lengths, its amount and both numbers of its offset, are multiplied by the length scale")
    func scalesDisplace() {
        // Given
        let sut = FilterOperation.displace(file: "/abs/ripple.png", amount: 8, offset: Point(x: -4, y: 2))

        // When
        let scaled = sut.scaled(by: 0.5)

        // Then
        #expect(scaled == .displace(file: "/abs/ripple.png", amount: 4, offset: Point(x: -2, y: 1)))
    }

    @Test("a number parameter stands for a displace amount and each number of its offset, never for its file")
    func fillsDisplaceParameters() throws {
        // Given
        let value = try Fixture.json(#"""
            { "description": "x",
              "params": { "strength": { "type": "number", "default": 6, "description": "the strength" },
                          "drift": { "type": "number", "default": -3, "description": "the drift" } },
              "ops": [ { "kind": "displace", "file": "/abs/ripple.png", "amount": { "param": "strength" },
                         "offset": [{ "param": "drift" }, 0] } ] }
            """#)
        let file = try Fixture.json(#"""
            { "description": "x", "params": { "n": { "type": "number", "default": 1, "description": "the n" } },
              "ops": [ { "kind": "displace", "file": { "param": "n" }, "amount": 4 } ] }
            """#)

        // When
        let preset = try sut.filter(from: value)
        let error = #expect(throws: (any Error).self) { try sut.filter(from: file) }

        // Then
        #expect(preset.operations == [.displace(file: "/abs/ripple.png", amount: 6, offset: Point(x: -3, y: 0))])
        #expect("\(error.map { "\($0)" } ?? "")" == "ops[0].file (displace): expected a string, found an object")
    }

    @Test("a preset with parameters is read with each parameter at its default")
    func readsParametersAtDefaults() throws {
        // Given
        let value = try Fixture.json(##"""
            { "description": "Dips to a colour and holds a beat, then the next clip comes up out of it.",
              "params": {
                "color": { "type": "color", "default": "#000000", "description": "colour of the dip" },
                "curve": { "type": "choice", "options": ["linear", "ease-in-out"], "default": "linear", "description": "pace of the fade" },
                "length": { "type": "number", "default": 0.7, "description": "the length" },
                "bounce": { "type": "choice", "options": [{ "kind": "spring", "bounce": 0.2 }, "ease-out"], "default": { "kind": "spring", "bounce": 0.2 }, "description": "the bounce" } },
              "seconds": { "param": "length" }, "ease": { "param": "curve" },
              "incoming": { "ease": { "param": "bounce" }, "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 0 }, { "t": 0.5, "opacity": 1 } ] },
              "cover": { "color": { "param": "color" },
                         "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 0.6, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
            """##)

        // When
        let preset = try sut.transition(from: value)

        // Then
        #expect(preset.seconds == 0.7)
        #expect(preset.cover?.source == .color("#000000"))
        #expect(preset.cover?.span.ease == .linear)
        #expect(preset.incoming?.ease == .spring(bounce: 0.2))
    }

    @Test("a number parameter stands for a key's value and t, a span's seconds and period, a softness and a bounce")
    func fillsNumberPlaces() throws {
        // Given
        let animation = try Fixture.json(#"""
            { "description": "x",
              "params": { "n": { "type": "number", "default": 0.5, "description": "the n" } },
              "entrance": { "seconds": { "param": "n" }, "ease": { "kind": "spring", "bounce": { "param": "n" } },
                            "keys": [ { "t": { "param": "n" }, "scale": { "param": "n" } } ] },
              "loop": { "period": { "param": "n" } } }
            """#)
        let transition = try Fixture.json(#"""
            { "description": "x", "params": { "soft": { "type": "number", "default": 0.25, "description": "the soft" } },
              "seconds": 1, "matte": { "media": "/abs/m.png", "softness": { "param": "soft" } } }
            """#)

        // When
        let readAnimation = try sut.animation(from: animation)
        let readTransition = try sut.transition(from: transition)

        // Then
        #expect(readAnimation.entrance?.length == 0.5)
        #expect(readAnimation.entrance?.span.ease == .spring(bounce: 0.5))
        #expect(readAnimation.entrance?.span.keys == [SpanKey(t: 0.5, values: [.scale: 0.5])])
        #expect(readAnimation.loop?.length == 0.5)
        #expect(readTransition.matte?.softness == 0.25)
    }

    @Test("a filter preset's number and colour parameters stand for an operation's numbers and its colour")
    func fillsFilterParameters() throws {
        // Given
        let value = try Fixture.json(##"""
            { "description": "x",
              "params": { "glow": { "type": "number", "default": 0.4, "description": "the glow" }, "tint": { "type": "color", "default": "#FFAA00", "description": "the tint" },
                          "black": { "type": "number", "default": 0.1, "description": "the black" } },
              "ops": [ { "kind": "bloom", "amount": { "param": "glow" }, "radius": 12, "color": { "param": "tint" } },
                       { "kind": "levels", "input": [{ "param": "black" }, 0.9], "output": [0, 1] } ] }
            """##)

        // When
        let preset = try sut.filter(from: value)

        // Then
        #expect(preset.operations == [.bloom(amount: 0.4, radius: 12, color: "#FFAA00"), .levels(input: [0.1, 0.9], output: [0, 1])])
    }

    @Test(
        "a preset's parameter is a number, a colour or a choice of eases with a default and a description, and is referred to",
        arguments: [
            (#"{ "p": { "type": "text", "default": "a", "description": "the p" } }"#, #"params.p.type (parameter): unknown value "text". Allowed: number, color, choice"#),
            (#"{ "p": { "type": "image", "default": "/abs/a.png", "description": "the p" } }"#, #"params.p.type (parameter): unknown value "image". Allowed: number, color, choice"#),
            (#"{ "p": { "type": "number", "description": "the p" } }"#, #"params.p (parameter): missing key "default""#),
            (#"{ "p": { "type": "number", "default": 1 } }"#, #"params.p (parameter): missing key "description""#),
            (#"{ "p": { "type": "choice", "options": ["linear", "linear"], "default": "linear", "description": "the p" } }"#, #"params.p.options (parameter): a choice offers at least two distinct options"#),
            (#"{ "p": { "type": "number", "default": "big", "description": "the p" } }"#, #"params.p.default (parameter): expected a number, found "big""#),
            (#"{ "p": { "type": "choice", "options": ["linear", "fast"], "default": "linear", "description": "the p" } }"#, #"params.p.options[1] (parameter): unknown value "fast". Allowed: linear, ease-in, ease-out, ease-in-out, back-out, bounce-out, step, [x1, y1, x2, y2], {spring}"#),
            (#"{ "p": { "type": "choice", "options": ["linear", "step"], "default": "ease-in", "description": "the p" } }"#, #"params.p.default (parameter): unknown value "ease-in". Allowed: linear, step"#),
            (#"{ "p": { "type": "number", "default": 1, "description": "the p" }, "unused": { "type": "number", "default": 1, "description": "the unused" } }"#, #"params.unused (parameter): "unused" is declared but nothing refers to it"#)
        ]
    )
    func refusesBrokenParameter(
        params: String,
        message: String
    ) throws {
        // Given
        let value = try Fixture.json(#"{ "description": "x", "params": \#(params), "seconds": { "param": "p" } }"#)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.transition(from: value) }
        #expect("\(error.map { "\($0)" } ?? "")" == message)
    }

    @Test(
        "a preset's parameter stands only where a value of its type is written, never for a name, a key or a file",
        arguments: [
            (#""seconds": 1, "cover": { "color": { "param": "n" } }"#, #"cover.color (cover): parameter "n" of type number cannot stand where a colour is expected"#),
            (#""seconds": { "param": "c" }"#, #"seconds (transition): parameter "c" of type color cannot stand where a number is expected"#),
            (#""seconds": { "param": "e" }"#, #"seconds (transition): parameter "e" of type choice cannot stand where a number is expected"#),
            (#""seconds": 1, "over": { "param": "e" }"#, "over (transition): expected one of incoming, outgoing, found an object"),
            (#""seconds": 1, "audio": { "param": "e" }"#, "audio (transition): expected one of constant-power, constant-gain, found an object"),
            (#""seconds": 1, "incoming": { "revealFrom": { "param": "e" } }"#, "incoming.revealFrom (incoming): expected one of left, right, top, bottom, found an object"),
            (#""seconds": 1, "matte": { "media": { "param": "n" } }"#, #"matte.media (page): unknown key "param". Allowed: file, page"#),
            (#""seconds": 1, "matte": { "media": "/abs/m.png", "invert": { "param": "n" } }"#, "matte.invert (matte): expected true or false, found an object")
        ]
    )
    func refusesMisplacedParameter(
        body: String,
        message: String
    ) throws {
        // Given
        let text = ##"""
            { "description": "x",
              "params": { "n": { "type": "number", "default": 1, "description": "the n" }, "c": { "type": "color", "default": "#000000", "description": "the c" },
                          "e": { "type": "choice", "options": ["linear", "step"], "default": "linear", "description": "the e" } },
            """## + body + "}"
        let value = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.transition(from: value) }
        #expect("\(error.map { "\($0)" } ?? "")" == message)
    }

    @Test(
        "a preset is checked with each parameter at its default, where a value its place does not take stops",
        arguments: [
            (#"{ "type": "number", "default": 0, "description": "the p" }"#, #""seconds": { "param": "p" }"#, "seconds (transition): a span runs for more than 0 seconds, found 0"),
            (#"{ "type": "number", "default": 1.5, "description": "the p" }"#, #""seconds": 1, "incoming": { "keys": [ { "t": 0, "opacity": { "param": "p" } } ] }"#, "incoming.keys[0].opacity (span key): 1.5 is not within 0 to 1"),
            (#"{ "type": "number", "default": 2, "description": "the p" }"#, #""seconds": 1, "incoming": { "keys": [ { "t": { "param": "p" } } ] }"#, "incoming.keys[0] (span key): t is progress through the span and lies between 0 and 1, found 2"),
            (#"{ "type": "number", "default": 1, "description": "the p" }"#, #""seconds": 1, "ease": { "kind": "spring", "bounce": { "param": "p" } }"#, "ease.spring.bounce (spring): 1 is not above -1 and below 1")
        ]
    )
    func refusesBrokenDefault(
        parameter: String,
        body: String,
        message: String
    ) throws {
        // Given
        let value = try Fixture.json(#"{ "description": "x", "params": { "p": \#(parameter) }, "# + body + "}")

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.transition(from: value) }
        #expect("\(error.map { "\($0)" } ?? "")" == message)
    }

    @Test("a filter preset's parameter is a number or a colour, and a range it breaks at its default stops")
    func refusesFilterChoiceAndRange() throws {
        // Given
        let choice = try Fixture.json(#"""
            { "description": "x", "params": { "p": { "type": "choice", "options": ["linear", "step"], "default": "linear", "description": "the p" } },
              "ops": [ { "kind": "sepia", "amount": 1 } ] }
            """#)
        let range = try Fixture.json(#"""
            { "description": "x", "params": { "p": { "type": "number", "default": 1.5, "description": "the p" } },
              "ops": [ { "kind": "sepia", "amount": { "param": "p" } } ] }
            """#)

        // When
        let choiceError = #expect(throws: (any Error).self) { try sut.filter(from: choice) }
        let rangeError = #expect(throws: (any Error).self) { try sut.filter(from: range) }

        // Then
        #expect("\(choiceError.map { "\($0)" } ?? "")" == #"params.p.type (parameter): unknown value "choice". Allowed: number, color"#)
        #expect("\(rangeError.map { "\($0)" } ?? "")" == "ops[0].amount (sepia): 1.5 is not within 0 to 1")
    }
}
