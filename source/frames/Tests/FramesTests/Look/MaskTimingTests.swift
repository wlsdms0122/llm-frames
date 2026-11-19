//
//  MaskTimingTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("Mask Timing Tests")
struct MaskTimingTests {
    // MARK: - Property
    private let sut = TimedValueBuilder()
    private let reader = LookReader()
    private let merger = LookMerger()
    private let place = LookPlace(clip: Place.root.appending(key: "clip"), key: "mask")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a mask's shape, invert or mode in a keyframe stops, naming the keyframe")
    func refusesStaticLeafInKeyframe() throws {
        // Given
        let written = try value(##"[{ "shape": "rect", "area": [0, 0, 10, 10] }]"##)

        // When, Then
        for key in ["shape", "invert", "mode"] {
            let json = key == "invert" ? "true" : (key == "mode" ? ##""subtract""## : ##""ellipse""##)
            let keyframes = try keyframes([(0, ##"[{ "\##(key)": \##(json) }]"##)])
            #expect(throws: LookError.keyframedStatic(place: place.keyframe(0).appending(index: 0).appending(key: key))) {
                try sut.ownLayer(written: written, keyframes: keyframes, as: LookStructureTable.mask, place: place)
            }
        }
    }

    @Test("a keyframe's mask list of another length, or a path of another number of points, stops")
    func refusesOtherLengths() throws {
        // Given
        let written = try value(##"[{ "shape": "path", "points": [[0, 0], [10, 0], [0, 10]] }]"##)
        let masks = try keyframes([(0, ##"[{ "feather": 1 }, { "feather": 2 }]"##)])
        let points = try keyframes([(0, ##"[{ "points": [[0, 0], [10, 0], [10, 10], [0, 10]] }]"##)])

        // When, Then
        #expect(throws: LookError.lengthsDiffer(place: place.keyframe(0), counts: [1, 2])) {
            try sut.ownLayer(written: written, keyframes: masks, as: LookStructureTable.mask, place: place)
        }
        #expect(throws: LookError.lengthsDiffer(place: place.keyframe(0).appending(index: 0).appending(key: "points"), counts: [3, 4])) {
            try sut.ownLayer(written: written, keyframes: points, as: LookStructureTable.mask, place: place)
        }
    }

    @Test("a keyframe's geometry in another form than the clip's or an earlier keyframe's stops")
    func refusesOtherGeometryForm() throws {
        // Given
        let written = try value(##"[{ "shape": "rect", "area": [0, 0, 10, 10] }]"##)
        let box = try keyframes([(0, ##"[{ "position": [5, 5] }]"##)])
        let bare = try value(##"[{ "shape": "rect" }]"##)
        let mixed = try keyframes([(0, ##"[{ "area": [0, 0, 10, 10] }]"##), (1, ##"[{ "width": 20 }]"##)])

        // When, Then
        #expect(throws: LookError.formsDiffer(place: place.keyframe(0).appending(index: 0).appending(key: "position"), forms: ["area", "position"])) {
            try sut.ownLayer(written: written, keyframes: box, as: LookStructureTable.mask, place: place)
        }
        #expect(throws: LookError.formsDiffer(place: place.keyframe(1).appending(index: 0).appending(key: "width"), forms: ["area", "width"])) {
            try sut.ownLayer(written: bare, keyframes: mixed, as: LookStructureTable.mask, place: place)
        }
    }

    @Test("a mask moved in every keyframe writes its geometry only there, and its keyframes give the form")
    func takesGeometryFormFromKeyframes() throws {
        // Given
        let written = try value(##"[{ "shape": "ellipse", "invert": true }]"##)
        let keyframes = try keyframes([(0, ##"[{ "area": [0, 0, 10, 10] }]"##), (2, ##"[{ "area": [10, 0, 10, 10], "feather": 4 }]"##)])

        // When
        let timed = try timed(written: written, keyframes: keyframes)

        // Then
        let mask = try #require(timed.first)
        #expect(mask["shape"] == .fixed(.string("ellipse")))
        #expect(mask["invert"] == .fixed(.bool(true)))
        #expect(mask["mode"] == .fixed(.string("add")))
        #expect(mask["area"] == .track([
            Keyframe(at: 0, value: .numbers([0, 0, 10, 10])),
            Keyframe(at: 2, value: .numbers([10, 0, 10, 10]))
        ]))
        #expect(mask["feather"] == .track([Keyframe(at: 2, value: .number(4))]))
    }

    @Test("a geometry leaf written on the clip and in every keyframe that writes it stops")
    func refusesStaticAndKeyframedGeometry() throws {
        // Given
        let written = try value(##"[{ "shape": "rect", "area": [0, 0, 10, 10] }]"##)
        let keyframes = try keyframes([(0, ##"[{ "area": [0, 0, 10, 10] }]"##), (1, ##"[{ "area": [5, 0, 10, 10] }]"##)])

        // When, Then
        #expect(throws: LookError.staticAndKeyframed(place: place.written.appending(index: 0).appending(key: "area"))) {
            try timed(written: written, keyframes: keyframes)
        }
    }

    // MARK: - Private
    private func value(_ json: String) throws -> LookValue {
        reader.value(of: try Fixture.json(json), as: LookStructureTable.mask)
    }

    private func keyframes(_ values: [(at: Double, json: String)]) throws -> [PropertyKeyframe<LookValue>] {
        try values.enumerated().map { index, entry in
            PropertyKeyframe(index: index, at: entry.at, value: try value(entry.json), ease: .linear)
        }
    }

    private func timed(
        written: LookValue,
        keyframes: [PropertyKeyframe<LookValue>]
    ) throws -> [TimedValue] {
        let structure = LookStructureTable.mask
        let own = try sut.ownLayer(written: written, keyframes: keyframes, as: structure, place: place)
        let merged = try #require(try merger.merge([own], as: structure, place: place.written))
        let timed = try sut.timed(merged, written: written, keyframes: keyframes, as: structure, instant: 0, place: place) { json, kind, _ in
            switch kind.form {
            case .numbers:
                .numbers((json.arrayValue ?? []).compactMap(\.numberValue))

            default:
                .number(json.numberValue ?? 0)
            }
        }
        guard case let .list(masks) = timed else { return [] }

        return masks
    }
}
