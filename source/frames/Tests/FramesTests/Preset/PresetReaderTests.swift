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
            (#"{ "description": "x", "exit": { "seconds": 1, "keys": [ { "t": 1, "blur": 1 } ] } }"#, #"exit.keys[0] (span key): unknown key "blur". Allowed: t, opacity, scale, x, y, rotation, reveal, nudge"#),
            (#"{ "description": "x", "exit": { "seconds": 1, "keys": [ { "opacity": 1 } ] } }"#, #"exit.keys[0] (span key): missing key "t""#),
            (#"{ "description": "x", "exit": { "seconds": 1, "keys": [ { "t": 1.5, "opacity": 1 } ] } }"#, "exit.keys[0] (span key): t is progress through the span and lies between 0 and 1, found 1.5"),
            (#"{ "description": "x", "entrance": { "seconds": 0 } }"#, "entrance.seconds (entrance): a span runs for more than 0 seconds, found 0"),
            (#"{ "description": "x", "entrance": { "seconds": 1, "revealFrom": "middle" } }"#, #"entrance.revealFrom (entrance): unknown value "middle". Allowed: left, right, top, bottom"#),
            (#"{ "description": "x", "intro": {} }"#, #"top level (animation): unknown key "intro". Allowed: description, entrance, loop, exit"#)
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
              "seconds": 0.45, "ease": "ease-in-out", "over": "incoming",
              "incoming": { "keys": [ { "t": 0, "y": 1 }, { "t": 1, "y": 0 } ] },
              "outgoing": { "ease": "linear", "keys": [ { "t": 0, "y": 0 }, { "t": 1, "y": -1 } ] },
              "cover":    { "color": "#FFFFFF", "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.4, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }
            """##)

        // When
        let preset = try sut.transition(from: value)

        // Then
        #expect(preset.seconds == 0.45)
        #expect(preset.over == .incoming)
        #expect(preset.incoming?.ease == .easeInOut)
        #expect(preset.outgoing?.ease == .linear)
        #expect(preset.cover?.source == .color("#FFFFFF"))
        #expect(preset.cover?.span.ease == .easeInOut)
        #expect(preset.cover?.span.keys.count == 3)
        #expect(preset.matte == nil)
    }

    @Test("a matte transition reads its media, softness and invert")
    func readsMatte() throws {
        // Given
        let value = try Fixture.json(#"{ "description": "luma wipe", "seconds": 1, "matte": { "media": "pack/gradient.png", "softness": 0.1, "invert": true } }"#)

        // When
        let preset = try sut.transition(from: value)

        // Then
        #expect(preset.over == .incoming)
        #expect(preset.matte == Matte(media: "pack/gradient.png", softness: 0.1, isInverted: true, ease: .linear))
    }

    @Test(
        "a transition preset with a broken rule stops",
        arguments: [
            (#"{ "description": "x", "seconds": 1, "incoming": { "seconds": 0.5, "keys": [] } }"#, #"incoming (incoming): unknown key "seconds". Allowed: ease, revealFrom, keys"#),
            (#"{ "description": "x", "seconds": 1, "outgoing": { "period": 0.5 } }"#, #"outgoing (outgoing): unknown key "period". Allowed: ease, revealFrom, keys"#),
            (#"{ "description": "x", "seconds": 1, "over": "outgoing", "matte": { "media": "/abs/m.png" } }"#, #"top level (transition): a matte reveals the incoming unit, so it cannot play with "over": "outgoing""#),
            (#"{ "description": "x" }"#, #"top level (transition): missing key "seconds""#),
            (#"{ "description": "x", "seconds": 1, "cover": { "keys": [] } }"#, "cover (cover): needs one of color, media"),
            (##"{ "description": "x", "seconds": 1, "cover": { "color": "#000000", "media": "/abs/s.mov" } }"##, #"cover (cover): takes only one of "color", "media""#),
            (##"{ "description": "x", "seconds": 1, "cover": { "color": "#000000", "keys": [ { "t": 0, "scale": 2 } ] } }"##, #"cover.keys[0] (cover key): unknown key "scale". Allowed: t, opacity"#),
            (#"{ "description": "x", "seconds": 1, "matte": { "softness": 0.2 } }"#, #"matte (matte): missing key "media""#),
            (#"{ "description": "x", "seconds": 1, "over": "above" }"#, #"over (transition): unknown value "above". Allowed: incoming, outgoing"#)
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
              { "op": "saturation", "amount": 0 }, { "op": "contrast", "amount": 1.3 },
              { "op": "levels", "input": [0.1, 0.9], "output": [0, 1] }, { "op": "lut", "file": "pack/warm", "amount": 0.5 },
              { "op": "bloom", "amount": 0.4, "radius": 12, "color": "#FFAA00" }, { "op": "grain", "amount": 0.2, "size": 2 }
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
              { "op": "sepia", "amount": 0 }, { "op": "lut", "file": "/abs/a.cube", "amount": 1 },
              { "op": "levels", "input": [0, 1], "output": [0.2, 0.8] }, { "op": "vignette", "amount": 0.5, "radius": 0 },
              { "op": "grain", "amount": 1, "size": 0.5 }, { "op": "pixelate", "size": 8 }
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
            (#"{ "description": "x", "ops": [ { "op": "glow", "amount": 1 } ] }"#, #"ops[0].op (filter operation): unknown value "glow". Allowed: exposure, contrast, saturation, temperature, hue, sepia, levels, lut, blur, sharpen, bloom, vignette, pixelate, grain"#),
            (#"{ "description": "x", "ops": [ { "amount": 1 } ] }"#, #"ops[0] (filter operation): missing key "op""#),
            (#"{ "description": "x", "ops": [ { "op": "blur", "radius": 2, "amount": 1 } ] }"#, #"ops[0] (blur): unknown key "amount". Allowed: op, radius"#),
            (#"{ "description": "x", "ops": [ { "op": "exposure" } ] }"#, #"ops[0] (exposure): missing key "ev""#),
            (#"{ "description": "x", "ops": [ { "op": "levels", "input": [0, 1, 2], "output": [0, 1] } ] }"#, "ops[0].input (levels): expected a list of 2 numbers, found a list of 3"),
            (#"{ "description": "x" }"#, #"top level (filter): missing key "ops""#),
            (#"{ "description": "x", "ops": [ { "op": "sepia", "amount": 1.5 } ] }"#, "ops[0].amount (sepia): 1.5 is not within 0 to 1"),
            (#"{ "description": "x", "ops": [ { "op": "lut", "file": "pack/warm", "amount": -0.1 } ] }"#, "ops[0].amount (lut): -0.1 is not within 0 to 1"),
            (#"{ "description": "x", "ops": [ { "op": "grain", "amount": 2, "size": 1 } ] }"#, "ops[0].amount (grain): 2 is not within 0 to 1"),
            (#"{ "description": "x", "ops": [ { "op": "grain", "amount": 0.2, "size": 0 } ] }"#, "ops[0].size (grain): 0 is not above 0"),
            (#"{ "description": "x", "ops": [ { "op": "levels", "input": [0, 1.2], "output": [0, 1] } ] }"#, "ops[0].input (levels): [0, 1.2] is not within 0 to 1 with black below white"),
            (#"{ "description": "x", "ops": [ { "op": "levels", "input": [0, 1], "output": [0.9, 0.1] } ] }"#, "ops[0].output (levels): [0.9, 0.1] is not within 0 to 1 with black below white"),
            (#"{ "description": "x", "ops": [ { "op": "levels", "input": [0.5, 0.5], "output": [0, 1] } ] }"#, "ops[0].input (levels): [0.5, 0.5] is not within 0 to 1 with black below white"),
            (#"{ "description": "x", "ops": [ { "op": "contrast", "amount": 1 }, { "op": "blur", "radius": -2 } ] }"#, "ops[1].radius (blur): -2 is not above 0"),
            (#"{ "description": "x", "ops": [ { "op": "sharpen", "amount": 1, "radius": 0 } ] }"#, "ops[0].radius (sharpen): 0 is not above 0"),
            (#"{ "description": "x", "ops": [ { "op": "bloom", "amount": 1, "radius": 0 } ] }"#, "ops[0].radius (bloom): 0 is not above 0"),
            (#"{ "description": "x", "ops": [ { "op": "pixelate", "size": -1 } ] }"#, "ops[0].size (pixelate): -1 is not above 0"),
            (#"{ "description": "x", "ops": [ { "op": "vignette", "amount": 0.5, "radius": 1.1 } ] }"#, "ops[0].radius (vignette): 1.1 is not within 0 to 1")
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
}
