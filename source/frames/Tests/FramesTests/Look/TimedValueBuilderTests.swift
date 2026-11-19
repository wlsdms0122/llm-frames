//
//  TimedValueBuilderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("TimedValueBuilder Tests")
struct TimedValueBuilderTests {
    // MARK: - Property
    private let sut = TimedValueBuilder()
    private let reader = LookReader()
    private let merger = LookMerger()
    private let place = LookPlace(clip: Place.root.appending(key: "clip"), key: "stroke")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a keyframe that writes only a stroke's colour keeps the style's width, and null points at it")
    func timesLeavesOverMergedValue() throws {
        // Given
        let style = try Fixture.json(##"{ "width": 6, "color": "#000000", "cap": "round" }"##)
        let keyframes = try keyframes([(0, ##"{ "width": 0 }"##), (1, ##"{ "width": null }"##), (2, ##"{ "color": "#FF0000" }"##)])

        // When
        let timed = try timed(style: style, written: nil, keyframes: keyframes)

        // Then
        #expect(timed["width"] == .track([Keyframe(at: 0, value: .number(0)), Keyframe(at: 1, value: .number(6))]))
        #expect(timed["color"] == .track([Keyframe(at: 2, value: .color(Color(written: "#FF0000")))]))
        #expect(timed["cap"] == .fixed(.string("round")))
        let sampled = timed.sampled(at: 0.5, as: LookStructureTable.stroke)
        #expect(sampled["width"]?.number == 3)
    }

    @Test("a static leaf, false or null for an object in a keyframe stops, naming the keyframe")
    func refusesStructureInKeyframe() throws {
        // Given
        let cap = try keyframes([(0, ##"{ "cap": "round" }"##)])
        let off = try keyframes([(0, "false")])

        // When, Then
        #expect(throws: LookError.keyframedStatic(place: place.keyframe(0).appending(key: "cap"))) {
            try sut.ownLayer(written: nil, keyframes: cap, as: LookStructureTable.stroke, place: place)
        }
        #expect(throws: LookError.keyframedOff(place: place.keyframe(0))) {
            try sut.ownLayer(written: nil, keyframes: off, as: LookStructureTable.stroke, place: place)
        }
    }

    @Test("a fill colour in keyframes replaces a style's other form, and a gradient keyframe over a colour stops")
    func takesKeyframeForm() throws {
        // Given
        let structure = ValueStructure.forms([("color", .leaf(.color)), ("linear", .object(ObjectStructure([])))])
        let colors = try keyframes([(0, ##""#FF0000""##), (1, ##""#0000FF""##)], as: structure)
        let gradient = try keyframes([(0, ##"{ "linear": {} }"##)], as: structure)
        let style = reader.value(of: try Fixture.json(##"{ "linear": {} }"##), as: structure)

        // When
        let own = try sut.ownLayer(written: nil, keyframes: colors, as: structure, place: place)
        let merged = try merger.merge([style, own], as: structure, place: place.written)

        // Then
        #expect(merged == .form("color", .unset))
        #expect(throws: LookError.formsDiffer(place: place.keyframe(0), forms: ["color", "linear"])) {
            try sut.ownLayer(written: .form("color", .leaf(.string("#FF0000"))), keyframes: gradient, as: structure, place: place)
        }
    }

    @Test("a leaf written statically and in every keyframe that writes it stops")
    func refusesStaticAndKeyframed() throws {
        // Given
        let keyframes = try keyframes([(0, ##"{ "width": 1 }"##), (1, ##"{ "width": 2 }"##)])
        let written = reader.value(of: try Fixture.json(##"{ "width": 4 }"##), as: LookStructureTable.stroke)

        // When, Then
        #expect(throws: LookError.staticAndKeyframed(place: place.written.appending(key: "width"))) {
            try timed(style: nil, written: written, keyframes: keyframes)
        }
    }

    @Test("a width of 0 is a domain value between two keyframes, and stops in a single keyframe, naming it")
    func checksDomain() throws {
        // Given
        let single = try keyframes([(0, ##"{ "width": 0 }"##)])
        let style = try Fixture.json(##"{ "width": 6 }"##)

        // When, Then
        #expect(throws: LookError.outsideDomain(place: place.keyframe(0).appending(key: "width"), value: 0)) {
            try timed(style: style, written: nil, keyframes: single)
        }
    }

    @Test("an ease that overshoots is clamped where the leaf is sampled")
    func clampsSamples() throws {
        // Given
        let timed = TimedValue.object([TimedMember(key: "width", value: .track([
            Keyframe(at: 0, value: .number(4), ease: .backOut),
            Keyframe(at: 1, value: .number(0))
        ]))])

        // When
        let sampled = timed.sampled(at: 0.8, as: LookStructureTable.stroke)

        // Then
        #expect(sampled["width"]?.number == 0)
    }

    // MARK: - Private
    private func keyframes(
        _ values: [(at: Double, json: String)],
        as structure: ValueStructure = LookStructureTable.stroke
    ) throws -> [PropertyKeyframe<LookValue>] {
        try values.enumerated().map { index, entry in
            PropertyKeyframe(index: index, at: entry.at, value: reader.value(of: try Fixture.json(entry.json), as: structure), ease: .linear)
        }
    }

    private func timed(
        style: JSONValue?,
        written: LookValue?,
        keyframes: [PropertyKeyframe<LookValue>]
    ) throws -> TimedValue {
        let structure = LookStructureTable.stroke
        let own = try sut.ownLayer(written: written, keyframes: keyframes, as: structure, place: place)
        let merged = try #require(try merger.merge([style.map { reader.value(of: $0, as: structure) }, own], as: structure, place: place.written))

        return try sut.timed(merged, written: written, keyframes: keyframes, as: structure, instant: 0, place: place) { json, kind, _ in
            switch kind.form {
            case .color:
                .color(Color(written: json.stringValue ?? "#000000"))

            default:
                .number(json.numberValue ?? 0)
            }
        }
    }
}
