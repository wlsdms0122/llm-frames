//
//  MediaKeyframeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Each case writes the same keys on the media clip `/abs/card.png` and on the storyline clip `/abs/screen.mp4`, in a
// 960 by 540 frame, so theme lengths are half their written size, and each document is checked by the key tables before
// it is planned. The theme `border` is 8 wide in `#FFFFFF`, and the theme `shadow` radius 20, offset [0, 8], `#00000080`.
@Suite("Media keyframe Tests")
struct MediaKeyframeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a static border of true and colour keyframes have one structure, and the colour moves at the theme's width")
    func movesBorderColour() throws {
        // When
        let looks = try resolvedLooks(##"""
            "border": true, "keyframes": [ { "at": 0, "border": "#FF0000" }, { "at": 1, "border": "#0000FF" } ]
            """##)

        // Then
        for look in looks {
            #expect(look.border.border(at: 0.5) == MediaBorder(width: 4, color: Color(written: "color(srgb 0.5 0 0.5)")))
        }
    }

    @Test("true in a border keyframe is the merged value, the clip's static colour over the theme's border")
    func pointsBorderKeyframeAtMergedValue() throws {
        // When
        let looks = try resolvedLooks(##"""
            "border": "#FF0000", "keyframes": [ { "at": 0, "border": "#0000FF" }, { "at": 1, "border": true } ]
            """##)

        // Then
        for look in looks {
            #expect(look.border.border(at: 0) == MediaBorder(width: 4, color: Color(written: "#0000FF")))
            #expect(look.border.border(at: 1) == MediaBorder(width: 4, color: Color(written: "#FF0000")))
        }
    }

    @Test("a radius and a shadow's leaves move between keyframes, a leaf written null ending on the theme's")
    func movesRadiusAndShadow() throws {
        // When
        let looks = try resolvedLooks(##"""
            "shadow": true,
            "keyframes": [ { "at": 0, "radius": 0, "shadow": { "radius": 0 } }, { "at": 1, "radius": 40, "shadow": { "radius": null } } ]
            """##)

        // Then
        for look in looks {
            #expect(look.radius.cornerRadii(at: 0.5) == 10)
            #expect(look.shadow.shadow(at: 0.5) == DropShadow(
                radius: 5,
                offset: Point(x: 0, y: 4),
                color: Color(written: "#00000080")
            ))
        }
    }

    @Test("a box without a border or a shadow draws none, and its radius is off")
    func drawsNoneUnwritten() throws {
        // When
        let looks = try resolvedLooks(#""opacity": 1"#)

        // Then
        for look in looks {
            #expect(look.radius == .off)
            #expect(look.border == .off)
            #expect(look.shadow == .off)
        }
    }

    @Test("a border object takes its missing keys from the theme border, its align inside by the base theme, and false draws none")
    func takesBorderObject() throws {
        // When
        let outside = try resolvedLooks(#""border": { "align": "outside" }"#)
        let coloured = try resolvedLooks(##""border": { "color": "#FF0000", "width": 2 }"##)
        let none = try resolvedLooks(#""border": false"#)

        // Then
        for look in outside {
            #expect(look.border.border() == MediaBorder(width: 4, color: Color(written: "#FFFFFF"), align: .outside))
        }
        for look in coloured {
            #expect(look.border.border() == MediaBorder(width: 1, color: Color(written: "#FF0000"), align: .inside))
        }
        for look in none {
            #expect(look.border == .off)
        }
    }

    @Test("a keyframe that writes a border's align stops on a media clip and a storyline clip alike, since align is static")
    func refusesKeyframedAlign() throws {
        // Given
        let keys = ##"""
            "border": true, "keyframes": [ { "at": 0, "border": { "align": "outside" } }, { "at": 1, "border": "#FF0000" } ]
            """##

        // When, Then
        let clipError = #expect(throws: (any Error).self) { try resolved(clip: keys) }
        let storylineError = #expect(throws: (any Error).self) { try resolved(storyline: keys) }
        #expect(clipError.map { "\($0)" } == "clips[0].keyframes[0].border.align (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe")
        #expect(storylineError.map { "\($0)" } == "storyline[0].keyframes[0].border.align (keyframe): a name, a boolean, a form or a static number is static and is written on the clip or the sequence, not in a keyframe")
    }

    @Test("a media clip's timed values read back from its resolved entry as they were written")
    func roundTripsTimedValues() throws {
        // Given
        let looks = try resolvedLooks(##"""
            "border": { "align": "outside" }, "shadow": { "color": "#000000" },
            "keyframes": [ { "at": 0, "radius": 4, "border": "#FF0000", "ease": "ease-in" }, { "at": 1, "radius": 8, "border": "#0000FF" } ]
            """##)
        let writer = ResolvedValueWriter()
        let reader = ResolvedValueReader()
        let place = Place.root.appending(key: "clips")

        // When
        let read = { (value: TimedValue, structure: ValueStructure, kind: String) in
            try reader.timed(PlacedJSONValue(writer.timed(value), place: place, kind: "image"), as: structure, kind: kind)
        }

        // Then
        for look in looks {
            #expect(try read(look.radius, LookStructureTable.radius, "radius") == look.radius)
            #expect(try read(look.border, LookStructureTable.border, "border") == look.border)
            #expect(try read(look.shadow, LookStructureTable.shadow, "shadow") == look.shadow)
        }
    }

    @Test("a shadow leaf written statically and in every keyframe stops on a media clip and a storyline clip alike")
    func refusesStaticAndKeyframedLeaf() throws {
        // Given
        let keys = #"""
            "shadow": { "radius": 2 }, "keyframes": [ { "at": 0, "shadow": { "radius": 2 } }, { "at": 1, "shadow": { "radius": 4 } } ]
            """#

        // When, Then
        let clipError = #expect(throws: (any Error).self) { try resolved(clip: keys) }
        let storylineError = #expect(throws: (any Error).self) { try resolved(storyline: keys) }
        #expect(clipError.map { "\($0)" } == "clips[0].shadow.radius: written as a static value and in every keyframe that writes it, so the static value never shows")
        #expect(storylineError.map { "\($0)" } == "storyline[0].shadow.radius: written as a static value and in every keyframe that writes it, so the static value never shows")
    }

    // MARK: - Private
    // The media clip's appearance, then the storyline clip's, as resolved.
    private func resolvedLooks(_ keys: String) throws -> [ResolvedMediaAppearance] {
        let clip = try resolved(clip: keys).clips[0]
        let storyline = try resolved(storyline: keys).storyline[0]
        guard case let .picture(.media(media), _) = clip.content else {
            Issue.record("the clip is media")
            return []
        }

        return [
            media.appearance,
            ResolvedMediaAppearance(
                conform: .fit,
                radius: storyline.radius,
                border: storyline.border,
                shadow: storyline.shadow
            )
        ]
    }

    private func resolved(
        clip keys: String? = nil,
        storyline storylineKeys: String? = nil
    ) throws -> ResolvedSequence {
        let storyline = storylineKeys.map { #"{ "media": "/abs/screen.mp4", \#($0) }"# } ?? #"{ "media": "/abs/screen.mp4" }"#
        let clips = keys.map { #"[ { "media": "/abs/card.png", "at": [0, 1], \#($0) } ]"# } ?? "[]"
        let document = #"""
            { "kind": "sequence", "format": { "size": [960, 540] },
              "theme": { "border": { "width": 8, "color": "#FFFFFF" },
                         "shadow": { "radius": 20, "offset": [0, 8], "color": "#00000080" } },
              "storyline": [ \#(storyline) ], "clips": \#(clips) }
            """#
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document))

        return try ResolvedSequence(plan: plan, hashes: FileHashTable())
    }
}
