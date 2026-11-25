//
//  SequenceCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Sequence Check Tests")
struct SequenceCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test("the sequence of the specification passes the key tables")
    func acceptsSpecificationExample() throws {
        // Given
        let document = try Fixture.json(#"""
            {
              "kind": "sequence",
              "format": { "size": [1080, 1920], "fps": 30, "background": "#000000", "conform": "fit" },
              "theme": { "defaults": { "transition": "frames/push-up", "filter": "frames/vivid", "animation": { "title": { "subtitle": "frames/pop" }, "shape": "frames/wipe" } } },
              "storyline": [
                { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "volume": 0,
                  "keyframes": [ { "at": 2, "crop": { "scale": 1 } }, { "at": 8, "crop": { "scale": 1.08 } } ],
                  "connected": [ { "at": [2, 8], "kind": "title", "text": "Subtitle", "style": "subtitle" } ] },
                { "kind": "media", "media": "/abs/run.mp4", "in": 17.5, "out": 23, "transition": "frames/flash", "volume": 0,
                  "keyframes": [ { "at": 18, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 19, "crop": [40, 300, 1000, 400] } ],
                  "connected": [ { "at": [19, 22], "kind": "rect", "stroke": { "width": 8 }, "area": [380, 900, 320, 120], "animation": "frames/stamp" },
                                 { "kind": "rect", "stroke": { "width": 8 }, "area": [120, 1200, 840, 100],
                                   "track": { "time": 17.5, "frames": [ { "time": 17.5, "quad": [[120, 1200], [960, 1200], [960, 1300], [120, 1300]] } ] } } ] },
                { "kind": "media", "media": "/abs/card.png", "duration": 2.5,
                  "transition": { "preset": "frames/wipe-right", "seconds": 0.5 },
                  "connected": [ { "kind": "rect", "stroke": { "width": 8 },
                                   "keyframes": [ { "at": 1.2, "area": [60, 400, 600, 80] }, { "at": 1.65, "area": [60, 500, 600, 80] } ] } ] }
              ],
              "clips": [
                { "at": [0, 30], "kind": "title", "text": "Top title\nSecond line", "style": "headline", "lane": 2 },
                { "at": [1, 6], "kind": "media", "media": "/abs/log.png", "width": 420, "radius": 24, "shadow": true,
                  "animation": { "entrance": "frames/pop", "exit": "frames/fade" }, "lane": 5,
                  "keyframes": [ { "at": 3, "position": [600, 500], "ease": "ease-in-out" }, { "at": 4, "position": [330, 900], "scale": 1.5 } ] },
                { "at": [0, 4], "kind": "media", "media": "/abs/light-leak.mov", "blend": "screen", "lane": 3 },
                { "kind": "media", "media": "/abs/bgm.m4a", "volume": 0.3, "loop": true, "fadeOut": 1 },
                { "at": 1.0, "kind": "media", "media": "/abs/ding.wav", "in": 0, "out": 1.5 }
              ]
            }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("an unknown key stops with its place, the clip kind and the allowed keys")
    func refusesUnknownKey() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": "/abs/run.mp4" }, { "kind": "media", "media": "/abs/run.mp4" },
              { "kind": "media", "media": "/abs/run.mp4", "connected": [ { "kind": "path", "points": [[0, 0], [10, 10]], "anim": "pop" } ] }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[2].connected[0] (path): unknown key "anim". Allowed: id, metadata, kind, at, lane, parent, opacity, blend, motionBlur, mask, trackMatte, track, animation, keyframes, style, position, anchor, fill, stroke, trim, shadow, scale, rotation, points, closed"#)
    }

    @Test(
        "a format takes no inset, in a document as in a compound clip",
        arguments: [
            (
                #"{ "kind": "sequence", "format": { "inset": [10, 10, 10, 10] }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#,
                #"format (format): unknown key "inset". Allowed: size, fps, background, conform, colorSpace, peak, compositing, motionBlur"#
            ),
            (
                #"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "sequence", "format": { "size": [640, 480], "inset": [10, 10, 10, 10] },
                  "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] } } ] }
                """#,
                #"storyline[0].media.format (format): unknown key "inset". Allowed: size, fps, background, conform, colorSpace, peak, compositing, motionBlur"#
            )
        ]
    )
    func refusesInset(
        document: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(document)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a value of the wrong type stops with its place")
    func refusesWrongType() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": "2" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].in (video): expected a number, found "2""#)
    }

    @Test("a scale is a number or a pair, in a keyframe as in a static value")
    func checksScale() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "kind": "rect", "fill": "accent", "area": [0, 0, 10, 10], "at": [0, 1], "scale": [2, 1],
                  "keyframes": [ { "at": 0, "scale": 0.5 }, { "at": 1, "scale": [1, 2, 3] } ] } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix("storyline[0].connected[0].keyframes[1].scale (") == true)
    }

    @Test(
        "a dash that is empty, holds a negative length or holds only zeros stops, in a keyframe as in a static value",
        arguments: [
            (#""stroke": { "dash": [] }"#, "stroke.dash"),
            (#""stroke": { "dash": [4, -1] }"#, "stroke.dash"),
            (#""stroke": { "dash": [0, 0] }"#, "stroke.dash"),
            (#""keyframes": [ { "at": 0, "stroke": { "dash": [0] } } ]"#, "keyframes[0].stroke.dash"),
            (#""keyframes": [ { "at": 0, "stroke": { "dash": [null, -1] } } ]"#, "keyframes[0].stroke.dash")
        ]
    )
    func refusesDash(
        stroke: String,
        key: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "kind": "rect", "area": [0, 0, 10, 10], "at": [0, 1], \#(stroke) } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix("storyline[0].connected[0].\(key) (") == true)
        #expect(error?.description.contains("each 0 or more and not all 0") == true)
    }

    @Test("a dash with gaps of 0, a negative dash offset and a keyframe dash of zeros and null lengths are taken")
    func takesDash() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "kind": "rect", "area": [0, 0, 10, 10], "at": [0, 1], "stroke": { "width": 2, "dash": [4, 0], "dashOffset": -3 },
                  "keyframes": [ { "at": 0, "stroke": { "dash": [0, null] } } ] } ] } ] }
            """#)

        // When, Then
        #expect(throws: Never.self) { try sut.check(document: document) }
    }

    @Test(
        "a gradient with fewer than two stops, an offset outside 0 to 1, a static offset below the one before, no kind, a kind of no gradient or a key of another kind, or a shape stroke's color or gradient stops",
        arguments: [
            (##""fill": { "kind": "linear", "from": [0, 0], "to": [1, 0], "stops": [[0, "#000000"]] }"##, "fill.stops ("),
            (##""fill": { "kind": "linear", "stops": [[0, "#000000"], [1.5, "#FFFFFF"]] }"##, "fill.stops[1][0] ("),
            (##""fill": { "kind": "radial", "stops": [[0.5, "#000000"], [0.2, "#FFFFFF"]] }"##, "fill.stops[1][0] ("),
            (##""fill": { "kind": "radial", "stops": [[0, "#000000"], [1, "#FFFFFF", 2]] }"##, "fill.stops[1] ("),
            (##""fill": { "from": [0, 0], "to": [1, 0], "stops": [[0, "#000000"], [1, "#FFFFFF"]] }"##, #"fill (rect): missing key "kind""#),
            (##""fill": { "kind": "conic", "stops": [[0, "#000000"], [1, "#FFFFFF"]] }"##, #"fill.kind (rect): unknown value "conic". Allowed: linear, radial"#),
            (##""fill": { "kind": "linear", "radius": 1, "stops": [[0, "#000000"], [1, "#FFFFFF"]] }"##, #"fill (linear gradient): unknown key "radius""#),
            (##""stroke": { "width": 2, "color": "#FFFFFF" }"##, #"stroke (stroke): unknown key "color""#),
            (##""stroke": { "width": 2, "gradient": { "kind": "radial", "stops": [[0, "#000000"], [1, "#FFFFFF"]] } }"##, #"stroke (stroke): unknown key "gradient""#),
            (##""keyframes": [ { "at": 0, "fill": { "kind": "linear", "stops": [[0, null], [1.5, null]] } } ]"##, "keyframes[0].fill.stops[1][0] ("),
            (##""keyframes": [ { "at": 0, "fill": { "stops": [[0, null], [1, null]] } } ]"##, #"keyframes[0].fill (keyframe): missing key "kind""#)
        ]
    )
    func refusesGradient(
        written: String,
        prefix: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "kind": "rect", "area": [0, 0, 10, 10], "at": [0, 1], \#(written) } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix("storyline[0].connected[0].\(prefix)") == true, "\(String(describing: error))")
    }

    @Test("a gradient fill, a stroke gradient, two stops at one offset, and null leaves and offsets out of order in a keyframe's stops are taken")
    func takesGradient() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "kind": "rect", "area": [0, 0, 10, 10], "at": [0, 1],
                  "fill": { "kind": "linear", "from": [0, 0], "to": [1, 1], "stops": [[0, "accent"], [0.5, "#FF0000"], [0.5, "#0000FF80"], [1, "#FFFFFF"]] },
                  "stroke": { "width": 2, "paint": { "kind": "radial", "center": [0.5, 0.5], "stops": [[0, "#000000"], [1, "#FFFFFF"]] } },
                  "keyframes": [ { "at": 0, "fill": { "kind": "linear", "stops": [[null, "#000000"], [0.6, null], [null, null], [0.2, null]] } } ] } ] } ] }
            """#)

        // When, Then
        #expect(throws: Never.self) { try sut.check(document: document) }
    }

    @Test("a number does not stand for a boolean")
    func refusesNumberForBool() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "loop": 1 } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error == .wrongType(place: Place(components: [.key("clips"), .index(0, id: nil), .key("loop")]), kind: "audio", expected: "true or false", found: "1"))
    }

    @Test("the first mistake in the file is the one reported")
    func stopsAtFirstMistake() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "speeed": 2, "fadein": 1 } ], "clip": [] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(#"storyline[0] (video): unknown key "speeed""#) == true)
    }

    @Test(
        "the media a clip holds picks its row of keys",
        arguments: [
            (#"{ "kind": "media", "media": "/abs/card.png", "duration": 2, "in": 1 }"#, "storyline", #"storyline[0] (image): unknown key "in""#),
            (#"{ "kind": "media", "media": "/abs/run.mp4", "duration": 2 }"#, "storyline", #"storyline[0] (video): unknown key "duration""#),
            (##"{ "kind": "solid", "color": "#000000", "duration": 2, "crop": [0, 0, 1, 1] }"##, "storyline", #"storyline[0] (solid): unknown key "crop""#),
            (#"{ "kind": "media", "media": "/abs/bgm.m4a", "lane": 2 }"#, "clips", #"clips[0] (audio): unknown key "lane""#),
            (#"{ "kind": "media", "media": "/abs/log.png", "at": [0, 1], "loop": true }"#, "clips", #"clips[0] (image): unknown key "loop""#),
            (#"{ "kind": "title", "text": "a", "style": "headline", "crop": [0, 0, 1, 1] }"#, "clips", #"clips[0] (title): unknown key "crop""#),
            (#"{ "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 1, 1], "side": "left" }"#, "clips", #"clips[0] (rect): unknown key "side""#),
            (#"{ "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 1, 1], "label": "x" }"#, "clips", #"clips[0] (rect): unknown key "label""#),
            (#"{ "kind": "adjustment", "adjust": "frames/vivid", "label": "x" }"#, "clips", #"clips[0] (adjustment): unknown key "label""#),
            (#"{ "id": "a", "kind": "media", "media": "/abs/run.mp4", "parent": "b" }"#, "storyline", #"storyline[0]#a (video): unknown key "parent""#),
            (##"{ "kind": "solid", "color": "#000000", "duration": 2, "parent": "b" }"##, "storyline", #"storyline[0] (solid): unknown key "parent""#),
            (#"{ "kind": "media", "media": "/abs/run.mp4", "placement": "top" }"#, "storyline", #"storyline[0] (video): unknown key "placement""#),
            (#"{ "kind": "media", "media": "/abs/bgm.m4a", "parent": "b" }"#, "clips", #"clips[0] (audio): unknown key "parent""#)
        ]
    )
    func picksRowByMedia(
        clip: String,
        list: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "\#(list)": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test("the media rows follow the kind the caller probed")
    func followsProbedKind() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/clip", "in": 1, "out": 2 } ] }"#)
        let still = KeyChecker(mediaKinds: MediaKindTable(["/abs/clip": .image]))
        let video = KeyChecker(mediaKinds: MediaKindTable(["/abs/clip": .video]))

        // When, Then
        #expect(throws: ModelError.self) { try still.check(document: document) }
        try video.check(document: document)
    }

    @Test("media that is not there stops")
    func refusesMissingMedia() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/unknown.mov" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].media (storyline clip): media "/abs/unknown.mov" is not there"#)
    }

    @Test("a storyline clip whose media holds only sound stops")
    func refusesSoundOnStoryline() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/bgm.m4a" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix("storyline[0] (audio):") == true)
    }

    @Test(
        "a clip is the kind its kind names, and a clip without one or of a kind its place does not take stops with the kinds it takes",
        arguments: [
            (#"{ "storyline": [ { "duration": 2 } ] }"#, #"storyline[0] (storyline clip): missing key "kind""#),
            (#"{ "clips": [ { "at": [0, 1] } ] }"#, #"clips[0] (clip): missing key "kind""#),
            (#"{ "storyline": [ { "kind": "title", "text": "a", "style": "headline" } ] }"#, #"storyline[0].kind (storyline clip): unknown value "title". Allowed: media, solid"#),
            (##"{ "clips": [ { "kind": "solid", "color": "#000000" } ] }"##, #"clips[0].kind (clip): unknown value "solid". Allowed: media, title, rect, ellipse, path, adjustment, null"#),
            (#"{ "clips": [ { "kind": "circle" } ] }"#, #"clips[0].kind (clip): unknown value "circle". Allowed: media, title, rect, ellipse, path, adjustment, null"#)
        ]
    )
    func tellsClipKindsApart(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a content key of another kind stops as an unknown key of the clip's kind",
        arguments: [
            (#"{ "clips": [ { "kind": "rect", "text": "a", "stroke": { "width": 8 }, "area": [0, 0, 1, 1] } ] }"#, #"clips[0] (rect): unknown key "text""#),
            (##"{ "clips": [ { "kind": "title", "text": "a", "style": "headline", "color": "#000000" } ] }"##, #"clips[0] (title): unknown key "color""#),
            (##"{ "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2, "text": "a" } ] }"##, #"storyline[0] (solid): unknown key "text""#)
        ]
    )
    func refusesContentKeyOfAnotherKind(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a clip without its kind's content stops",
        arguments: [
            (#"{ "storyline": [ { "kind": "media" } ] }"#, #"storyline[0] (media): missing key "media""#),
            (#"{ "storyline": [ { "kind": "solid", "duration": 2 } ] }"#, #"storyline[0] (solid): missing key "color""#),
            (#"{ "clips": [ { "kind": "title", "style": "headline", "at": [0, 1] } ] }"#, #"clips[0] (title): missing key "text""#),
            (#"{ "clips": [ { "kind": "adjustment", "at": [0, 1] } ] }"#, #"clips[0] (adjustment): missing key "adjust""#)
        ]
    )
    func refusesMissingContent(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a title names its style")
    func requiresTitleStyle() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "title", "text": "Hello", "at": [0, 1] } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"clips[0] (title): missing key "style""#)
    }

    @Test(
        "a key a shape kind does not take stops",
        arguments: [
            (#"{ "kind": "ellipse", "area": [0, 0, 10, 10], "radius": 4 }"#, #"clips[0] (ellipse): unknown key "radius""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 10]], "radius": 4 }"#, #"clips[0] (path): unknown key "radius""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 10]], "outset": 4 }"#, #"clips[0] (path): unknown key "outset""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 10]], "area": [0, 0, 10, 10] }"#, #"clips[0] (path): unknown key "area""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 10]], "width": 10 }"#, #"clips[0] (path): unknown key "width""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 10]], "height": 10 }"#, #"clips[0] (path): unknown key "height""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 10]], "placement": "top" }"#, #"clips[0] (path): unknown key "placement""#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "points": [[0, 0], [10, 10]] }"#, #"clips[0] (rect): unknown key "points""#),
            (#"{ "kind": "ellipse", "area": [0, 0, 10, 10], "closed": true }"#, #"clips[0] (ellipse): unknown key "closed""#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "color": "accent" }"#, #"clips[0] (rect): unknown key "color""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 10]], "keyframes": [ { "at": 0, "radius": 2 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "radius""#)
        ]
    )
    func refusesKeyOfOtherShapeKind(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a shape's appearance keys stop where their form is wrong",
        arguments: [
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "fill": true }"#, #"clips[0].fill (rect): expected "#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "stroke": true }"#, #"clips[0].stroke (rect): expected "#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "join": "square" } }"#, #"clips[0].stroke.join (stroke): unknown value "square". Allowed: miter, round, bevel"#),
            (#"{ "kind": "path", "points": [[0, 0], [9, 9]], "stroke": { "width": 2, "end": { "shape": "frames/arrow" } } }"#, #"clips[0].stroke.end (end): unknown key "shape". Allowed: preset, scale"#),
            (#"{ "kind": "path", "points": [[0, 0], [9, 9]], "stroke": { "width": 2, "end": { "preset": "frames/arrow", "scale": 0 } } }"#, #"clips[0].stroke.end.scale (end): 0 is not above 0"#),
            (#"{ "kind": "path", "points": [[0, 0], [9, 9]], "stroke": { "width": 2, "end": { "preset": "frames/arrow", "scale": -1 } } }"#, #"clips[0].stroke.end.scale (end): -1 is not above 0"#),
            (#"{ "kind": "path", "points": [[0, 0], [9, 9]], "stroke": { "width": 2, "end": { "preset": "frames/arrow", "size": 2 } } }"#, #"clips[0].stroke.end (end): unknown key "size". Allowed: preset, scale"#),
            (#"{ "kind": "path", "points": [[0, 0], [9, 9]], "stroke": { "width": 2, "end": false } }"#, #"clips[0].stroke.end (stroke): expected "#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "head": 8 } }"#, #"clips[0].stroke (stroke): unknown key "head""#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "trim": [0, 1.5] }"#, #"clips[0].trim[1] (rect): 1.5 is not within 0 to 1"#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "trim": [0.5] }"#, #"clips[0].trim (rect): expected a list of 2 numbers, each within 0 to 1"#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "shadow": "soft" }"#, #"clips[0].shadow (rect): expected "#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "shadow": { "blur": 4 } }"#, #"clips[0].shadow (shadow): unknown key "blur""#),
            (#"{ "kind": "path", "points": [[0, 0]], "fill": "accent" }"#, #"clips[0].points (path): expected a list of at least two vertices, each [x, y] or {vertex, inTangent, outTangent}"#),
            (#"{ "kind": "path", "points": [[0, 0], "top"], "fill": "accent" }"#, #"clips[0].points[1] (path): expected "#),
            (#"{ "kind": "path", "points": [[0, 0], [1, 1]], "closed": 1, "fill": "accent" }"#, #"clips[0].closed (path): expected "#)
        ]
    )
    func refusesWrongShapeForm(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a look number outside its leaf's domain stops where it is written, naming the domain",
        arguments: [
            (
                #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 0 } } ] }"#,
                "clips[0].stroke.width (stroke): 0 is not above 0"
            ),
            (
                ##"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": "#FFFFFF", "outset": -1 } ] }"##,
                "clips[0].outset (rect): -1 is not 0 or more"
            ),
            (
                #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": { "kind": "radial", "radius": 0 } } ] }"#,
                "clips[0].fill.radius (radial gradient): 0 is not above 0"
            ),
            (
                #"{ "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "radius": -8 } ] }"#,
                "clips[0].radius (image): -8 is not 0 or more"
            ),
            (
                #"{ "clips": [ { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 1], "mask": { "kind": "rect", "area": [0, 0, 10, 10], "feather": -1 } } ] }"#,
                "clips[0].mask.feather (rect mask): -1 is not 0 or more"
            ),
            (
                #"{ "clips": [ { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 1], "mask": { "kind": "rect", "width": 0, "height": 10, "position": [5, 5] } } ] }"#,
                "clips[0].mask.width (rect mask): 0 is not above 0"
            )
        ]
    )
    func refusesLookNumberOutsideDomain(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a shape takes its appearance keys in every form they have",
        arguments: [
            #"{ "kind": "rect", "width": 100, "height": 50, "placement": "top", "radius": 8, "outset": 2, "fill": false, "stroke": { "paint": "accent", "width": 4, "join": "miter", "cap": "square", "start": "frames/arrow", "end": "none" }, "shadow": true }"#,
            ##"{ "kind": "ellipse", "area": [0, 0, 10, 10], "fill": "#FFFFFF80", "stroke": false, "trim": [0.25, 0], "shadow": { "radius": 4 } }"##,
            #"{ "kind": "path", "points": [[0, 0], [9, 9]], "stroke": { "width": 2, "start": "frames/line-arrow", "end": { "preset": "frames/circle", "scale": 2 } } }"#,
            #"{ "kind": "path", "points": [[0, 0], [9, 9]], "stroke": { "width": 2, "start": { "scale": 1.5 }, "end": "/abs/heads/bar.json" } }"#,
            #"{ "kind": "path", "points": [[0, 0], { "vertex": { "area": [0, 0, 10, 10], "point": "center" } }], "closed": true, "style": "outline", "shadow": false }"#,
            #"{ "kind": "path", "fill": "accent", "keyframes": [ { "at": 0, "points": [[0, 0], [2, 2]], "trim": [0, 0.5], "position": [1, 1], "scale": 2, "rotation": 90 } ] }"#,
            #"{ "kind": "rect", "fill": "accent", "keyframes": [ { "at": 0, "width": 10, "height": 20, "radius": 2, "area": [0, 0, 1, 1] } ] }"#
        ]
    )
    func takesShapeForms(clip: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ \#(clip) ] }"#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a media clip and a storyline clip take a shadow of true, false or an object, and an object with another key stops",
        arguments: [
            (#"true"#, nil),
            (#"false"#, nil),
            (#"{ "radius": 4, "offset": [0, 2], "color": "accent" }"#, nil),
            (#"{ "blur": 4 }"#, #"(shadow): unknown key "blur""#),
            (#""soft""#, #"(image): expected "#)
        ] as [(String, String?)]
    )
    func checksMediaShadow(
        shadow: String,
        message: String?
    ) throws {
        // Given
        let clip = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "media", "media": "/abs/log.png", "at": [0, 1], "shadow": \#(shadow) } ] }"#)
        let storyline = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/log.png", "shadow": \#(shadow) } ] }"#)

        // When, Then
        guard let message else {
            try sut.check(document: clip)
            try sut.check(document: storyline)
            return
        }
        let clipError = #expect(throws: ModelError.self) { try sut.check(document: clip) }
        let storylineError = #expect(throws: ModelError.self) { try sut.check(document: storyline) }
        #expect(clipError?.description.hasPrefix("clips[0].shadow \(message)") == true, "\(clipError?.description ?? "no error")")
        #expect(
            storylineError?.description.hasPrefix("storyline[0].shadow \(message)") == true,
            "\(storylineError?.description ?? "no error")"
        )
    }

    @Test("a property written both as a static value and in a keyframe stops")
    func refusesStaticAndKeyframed() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [
              { "kind": "media", "media": "/abs/log.png", "at": [0, 4], "scale": 1, "keyframes": [ { "at": 1, "scale": 2 } ] }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error == .staticAndKeyframed(place: Place(components: [.key("clips"), .index(0, id: nil)]), kind: "image", property: "scale"))
    }

    @Test(
        "a keyframe takes only the keyframable properties of its clip",
        arguments: [
            (#"{ "kind": "adjustment", "adjust": "frames/vivid", "keyframes": [ { "at": 1, "position": [0, 0] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "position". Allowed: at, ease, opacity, mask, adjust"#),
            (#"{ "kind": "path", "points": [[0, 0], [1, 1]], "keyframes": [ { "at": 1, "area": [0, 0, 1, 1] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "area". Allowed: at, ease, points, position, scale, rotation, opacity, trim, fill, stroke, shadow, mask"#),
            (#"{ "kind": "ellipse", "keyframes": [ { "at": 1, "radius": 2 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "radius". Allowed: at, ease, area, width, height, position, scale, rotation, cornerPin, opacity, trim, outset, fill, stroke, shadow, mask"#),
            (#"{ "kind": "title", "text": "a", "style": "headline", "keyframes": [ { "at": 1, "crop": [0, 0, 1, 1] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "crop". Allowed: at, ease, position, scale, rotation, cornerPin, opacity, mask, character, paragraph"#),
            (#"{ "kind": "media", "media": "/abs/bgm.m4a", "keyframes": [ { "at": 1, "opacity": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "opacity". Allowed: at, ease, volume, pan, audioFilter"#),
            (#"{ "kind": "media", "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1, "volume": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "volume". Allowed: at, ease, position, scale, rotation, cornerPin, opacity, crop, mask, filter, radius, border, shadow"#),
            (#"{ "kind": "media", "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1 } ] }"#, "clips[0].keyframes[0] (keyframe): needs one of position, scale, rotation, cornerPin, opacity, crop, mask, filter, radius, border, shadow"),
            (#"{ "kind": "media", "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "scale": 1 } ] }"#, #"clips[0].keyframes[0] (keyframe): missing key "at""#)
        ]
    )
    func checksKeyframeKeys(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a storyline clip keyframes its crop, and its volume only on timed media")
    func keyframesStorylineCrop() throws {
        // Given
        let still = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/card.png", "keyframes": [ { "at": 0, "volume": 1 } ] } ] }"#)
        let video = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "keyframes": [ { "at": 0, "volume": 1 }, { "at": 1, "crop": { "scale": 2 } } ] } ] }"#)

        // When, Then
        #expect(throws: ModelError.self) { try sut.check(document: still) }
        try sut.check(document: video)
    }

    @Test("`pan` is keyframable on an audio clip, a connected video and a storyline video")
    func keyframesPan() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": "/abs/run.mp4", "pan": 0.2, "connected": [
                { "kind": "media", "media": "/abs/run.mp4", "at": [0, 1], "keyframes": [ { "at": 0, "pan": -1 }, { "at": 1, "pan": 1 } ] }
              ], "keyframes": [] }
            ], "clips": [
              { "kind": "media", "media": "/abs/bgm.m4a", "keyframes": [ { "at": 0, "pan": -0.5, "ease": "ease-in-out" }, { "at": 2, "pan": 0.5 } ] }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a `pan` outside -1 to 1 stops as a value of the wrong type")
    func refusesPanOutOfRange() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "pan": 1.5 } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "clips[0].pan (audio): 1.5 is not within -1 to 1")
    }

    @Test("a still takes no `pan`, since it plays no sound")
    func refusesPanOnStill() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "media", "media": "/abs/log.png", "at": [0, 1], "pan": 0 } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        guard case let .unknownKey(_, kind, key, _) = error else {
            Issue.record("expected an unknown key, found \(String(describing: error))")
            return
        }
        #expect(kind == "image")
        #expect(key == "pan")
    }

    @Test("a storyline clip with media takes a transform and draws its box, keyframing its position, scale, rotation and opacity")
    func acceptsStorylineTransform() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": "/abs/card.png", "duration": 2, "anchor": "top-left", "blend": "screen", "radius": 12, "border": true, "shadow": true,
                "keyframes": [ { "at": 0, "position": [0, 0], "scale": 1, "rotation": 0, "opacity": 1 }, { "at": 2, "position": [10, 0], "scale": 0.5, "rotation": 90, "opacity": 0 } ] },
              { "kind": "media", "media": "/abs/run.mp4", "position": [540, 960], "scale": 0.5, "rotation": 10, "opacity": 0.8 }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a storyline clip takes no placement and no parent, and a solid no transform",
        arguments: [
            (
                #"{ "kind": "media", "media": "/abs/run.mp4", "parent": "intro" }"#,
                #"storyline[0] (video): unknown key "parent". Allowed: id, metadata, kind, media, colorSpace, toneMap, in, out, speed, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, track, radius, border, shadow, volume, pan, fadeIn, fadeOut, audioFilter, split, keyframes, connected"#
            ),
            (
                #"{ "kind": "media", "media": "/abs/card.png", "duration": 2, "placement": "top" }"#,
                #"storyline[0] (image): unknown key "placement". Allowed: id, metadata, kind, media, colorSpace, toneMap, duration, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, radius, border, shadow, keyframes, connected"#
            ),
            (
                ##"{ "kind": "solid", "color": "#FF0000", "duration": 2, "scale": 2 }"##,
                #"storyline[0] (solid): unknown key "scale". Allowed: id, metadata, kind, color, duration, transition, motionBlur, keyframes, connected"#
            )
        ]
    )
    func refusesStorylineKey(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a storyline solid takes no transform key, statically or in a keyframe, so its transform is always the identity",
        arguments: [
            (#""anchor": "top-left""#, "storyline[0]", "solid", "anchor"),
            (#""position": [0, 0]"#, "storyline[0]", "solid", "position"),
            (#""scale": 2"#, "storyline[0]", "solid", "scale"),
            (#""rotation": 90"#, "storyline[0]", "solid", "rotation"),
            (#""keyframes": [ { "at": 0, "position": [0, 0] } ]"#, "storyline[0].keyframes[0]", "keyframe", "position")
        ]
    )
    func refusesSolidTransform(
        key: String,
        place: String,
        kind: String,
        name: String
    ) throws {
        // Given
        let document = try Fixture.json(##"{ "kind": "sequence", "storyline": [ { "kind": "solid", "color": "#FF0000", "duration": 2, \##(key) } ] }"##)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(#"\#(place) (\#(kind)): unknown key "\#(name)". Allowed: "#) == true)
    }

    @Test("an id is a string unique within its document, and a nested document has its own")
    func checksIdentifiers() throws {
        // Given
        let duplicate = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "id": "a", "kind": "title", "text": "x", "style": "s" }, { "id": "a", "kind": "rect", "stroke": { "width": 8 } } ] }"#)
        let nested = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "id": "a", "kind": "media", "media": { "kind": "sequence", "storyline": [ { "id": "a", "kind": "media", "media": "/abs/run.mp4" } ] } }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: duplicate) }
        #expect(error?.description == #"clips[1]#a (rect): id "a" is already used at clips[0]#a"#)
        try sut.check(document: nested)
    }

    @Test(
        "a request stops at the place it stands, naming the tool that fills it, wherever a value stands",
        arguments: [
            (
                #"{ "id": "box", "kind": "rect", "parent": "shot", "area": { "tool": "frames/find-text", "text": "Total", "padding": 8 } }"#,
                "storyline[0]#shot.connected[0]#box.area",
                "frames/find-text"
            ),
            (
                #"{ "kind": "rect", "parent": "shot", "area": [10, 10, 50, 50], "track": { "tool": "frames/track-motion", "target": "area" } }"#,
                "storyline[0]#shot.connected[0].track",
                "frames/track-motion"
            ),
            (
                #"{ "kind": "rect", "parent": "shot", "keyframes": [ { "at": 0, "area": [10, 10, 50, 50] }, { "at": 1, "area": { "tool": "frames/find-text", "text": "Total" } } ] }"#,
                "storyline[0]#shot.connected[0].keyframes[1].area",
                "frames/find-text"
            ),
            (
                #"{ "kind": "path", "parent": "shot", "points": [ [0, 0], { "vertex": { "area": { "tool": "frames/find-text", "from": "Total", "to": "42,000" }, "point": "right" } } ] }"#,
                "storyline[0]#shot.connected[0].points[1].vertex.area",
                "frames/find-text"
            ),
            (
                #"{ "kind": "path", "parent": "shot", "points": [ [0, 0], { "tool": "studio/pointer", "at": "cursor" } ] }"#,
                "storyline[0]#shot.connected[0].points[1]",
                "studio/pointer"
            ),
            (
                #"{ "kind": "rect", "parent": "shot", "area": [10, 10, 50, 50], "opacity": { "tool": "studio/fader", "param": "level" } }"#,
                "storyline[0]#shot.connected[0].opacity",
                "studio/fader"
            ),
            (
                #"{ "tool": "studio/captions", "transcript": "/abs/talk.srt" }"#,
                "storyline[0]#shot.connected[0]",
                "studio/captions"
            )
        ]
    )
    func refusesRequest(
        connected: String,
        place: String,
        tool: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "shot", "kind": "media", "media": "/abs/run.mp4", "connected": [ \#(connected) ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "\(place) (request): this is a request for the tool \"\(tool)\", and a tool fills its requests before the document is given to frames")
    }

    @Test("a request whose tool is not text stops on its tool")
    func refusesRequestWithoutToolName() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [ { "kind": "rect", "area": { "tool": 1, "text": "Total" } } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "storyline[0].connected[0].area.tool (request): expected a string, found 1")
    }

    @Test("a request stops where it stands as an argument of a preset choice")
    func refusesRequestAsArgument() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": { "preset": "frames/vivid", "args": { "amount": { "tool": "studio/grader" } } } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].filter.args.amount (request): this is a request for the tool "studio/grader", and a tool fills its requests before the document is given to frames"#)
    }

    @Test("a tool key inside metadata is no request")
    func leavesToolInMetadata() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "rect", "metadata": { "tool": "studio/autocut", "cut": { "tool": "studio/autocut" } } } ] }"#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("metadata is an object whose contents are not checked")
    func leavesMetadataUnchecked() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "rect", "metadata": { "by": "redactor", "anything": [1, { "param": "x" }] } } ] }"#)
        let notObject = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "rect", "metadata": "note" } ] }"#)

        // When, Then
        try sut.check(document: document)
        #expect(throws: ModelError.self) { try sut.check(document: notObject) }
    }

    @Test(
        "values of the wrong form stop",
        arguments: [
            #"{ "clips": [ { "kind": "title", "text": "a", "style": "s", "at": 2 } ] }"#,
            #"{ "clips": [ { "kind": "title", "text": "a", "style": "s", "parent": true, "position": [0, 0] } ] }"#,
            #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "parent": 1 } ] }"#,
            #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "lane": 1.5 } ] }"#,
            ##"{ "clips": [ { "kind": "rect", "fill": "#12345" } ] }"##,
            #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "blend": "linear-dodge" } ] }"#,
            #"{ "clips": [ { "kind": "title", "text": "a", "style": "s", "placement": "middle" } ] }"#,
            #"{ "clips": [ { "kind": "media", "media": "/abs/log.png", "at": [0, 1], "border": 4 } ] }"#,
            #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "opacity": 1, "ease": "ease" } ] } ] }"#,
            #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "opacity": 1, "ease": [1.2, 0, 0.5, 1] } ] } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "transition": { "preset": "frames/flash" } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": ["frames/vivid", 2] } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "crop": { "middle": "a" } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "crop": { "scale": 0 } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "crop": { "scale": -1 } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "keyframes": [ { "at": 0, "crop": { "scale": 0 } } ] } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": { "imageSequence": "/abs/frames" } } ] }"#,
            #"{ "format": { "size": [1080] } }"#,
            #"{ "format": { "conform": "stretch" } }"#
        ]
    )
    func refusesWrongForms(body: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        #expect(throws: ModelError.self) { try sut.check(document: document) }
    }

    @Test("a clip takes the non-separable blend modes", arguments: ["hue", "saturation", "color", "luminosity"])
    func acceptsNonSeparableBlend(mode: String) throws {
        // Given
        let document = try Fixture.json(
            #"{ "kind": "sequence", "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "blend": "\#(mode)" } ] }"#
        )

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "an area written in a removed form, or with a size or padding it cannot take, stops where it is written",
        arguments: [
            (
                #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "crop": "Total" } ] }"#,
                #"storyline[0].crop (video): expected an area or {scale}, found "Total""#
            ),
            (
                #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "crop": { "band": { "text": "Total" } } } ] }"#,
                #"storyline[0].crop (clip area): unknown key "band". Allowed: clip, padding"#
            ),
            (
                #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 0, 10] } ] }"#,
                "clips[0].area[2] (rect): 0 is not above 0"
            ),
            (
                #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "area": [0, 0, 10, -1] } ] } ] }"#,
                "clips[0].keyframes[0].area[3] (keyframe): -1 is not above 0"
            ),
            (
                #"{ "clips": [ { "kind": "title", "text": "a", "style": "s", "position": { "area": "Send", "point": "left" } } ] }"#,
                #"clips[0].position.area (area point): expected an area, found "Send""#
            )
        ]
    )
    func refusesAreaForms(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("an area that names a place by its text stops at the key check, its text key unknown to a clip area")
    func refusesTextArea() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "area": { "text": "Total" } } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0]#screen.connected[0].area (clip area): unknown key "text". Allowed: clip, padding"#)
    }

    @Test(
        "a content fit size takes only `fit` as \"content\" and a margin of whole pixels 0 or more in one of its forms",
        arguments: [
            (#"{ "fit": "page" }"#, #"format.size.fit (content fit): unknown value "page". Allowed: content"#),
            (#"{ "margin": 4 }"#, #"format.size (content fit): missing key "fit""#),
            (#"{ "fit": "content", "padding": 4 }"#, #"format.size (content fit): unknown key "padding". Allowed: fit, margin"#),
            (#"{ "fit": "content", "margin": -1 }"#, "format.size.margin (content fit): expected a whole number, 0 or more, found -1"),
            (#"{ "fit": "content", "margin": 1.5 }"#, "format.size.margin (content fit): expected a whole number, 0 or more, found 1.5"),
            (#"{ "fit": "content", "margin": [1, 2, 3] }"#, "format.size.margin (content fit): expected a whole number, 0 or more, or a list of 2 or 4 of them, found a list of 3"),
            (#"{ "fit": "content", "margin": [1, -2] }"#, "format.size.margin[1] (content fit): expected a whole number, 0 or more, found -2"),
            (#"{ "fit": "content", "margin": "4" }"#, #"format.size.margin (content fit): expected a whole number, 0 or more, or a list of 2 or 4 of them, found "4""#)
        ]
    )
    func refusesContentFitForms(
        size: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": \#(size) }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "every form the specification gives a value is taken",
        arguments: [
            #"{ "clips": [ { "kind": "media", "media": "/abs/run.mp4", "at": 2 } ] }"#,
            #"{ "clips": [ { "kind": "media", "media": "/abs/log.png", "at": [0, 1], "border": "accent", "conform": "fill", "anchor": "top-left" } ] }"#,
            #"{ "storyline": [ { "id": "run", "kind": "media", "media": "/abs/run.mp4", "connected": [ { "kind": "title", "text": "a", "style": "s", "parent": "run", "position": { "area": [400, 1200, 200, 60], "point": "left" }, "anchor": "right" } ] } ] }"#,
            #"{ "clips": [ { "kind": "title", "text": "a", "style": "s", "parent": "run", "position": { "area": [400, 1200, 200, 60], "point": "left" } }, { "kind": "rect", "stroke": { "width": 8 }, "parent": "run", "area": [400, 1200, 200, 60] } ] }"#,
            #"{ "clips": [ { "id": "box", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10] }, { "kind": "rect", "stroke": { "width": 8 }, "area": { "clip": "box", "padding": 40 } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "crop": [0, 0, 540, 960], "track": { "time": 0, "frames": [ { "time": 0, "quad": [[0, 0], [0.5, 0], [0.5, 0.5], [0, 0.5]] } ] } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": { "imageSequence": "/abs/frames", "fps": 30 }, "in": 0, "out": 2 } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": ["frames/vivid", "pack/warm", "/abs/f.json"], "transition": "cut" } ] }"#,
            #"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "opacity": 1, "ease": [0.25, 0.1, 0.25, 1] }, { "at": 1, "opacity": 0 } ] } ] }"#,
            #"{ "clips": [ { "kind": "path", "points": [[0, 0], [10, 10]], "stroke": { "width": 4, "end": "frames/arrow" }, "animation": { "entrance": "frames/pop", "exit": "none" } } ] }"#,
            ##"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "transition": { "preset": "studio/dip", "seconds": 1, "args": { "color": "#1B3A6B" } } } ] }"##,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "transition": { "preset": "studio/dip", "args": { "curve": "linear" } } } ] }"#,
            #"{ "clips": [ { "kind": "title", "text": "a", "style": "s", "animation": { "preset": "studio/spring-in", "args": { "bounce": 0.4 } } } ] }"#,
            #"{ "clips": [ { "kind": "title", "text": "a", "style": "s", "animation": { "entrance": { "preset": "studio/spring-in", "args": { "ease": { "spring": { "bounce": 0.4 } } } }, "exit": "frames/fade" } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": { "preset": "studio/film", "args": { "grain": 0.02 } } } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": ["frames/warm", { "preset": "studio/film", "args": { "grain": 0.02 } }, { "preset": "studio/film", "args": { "grain": 0.04 } }] } ] }"#,
            ##"{ "theme": { "defaults": { "transition": { "preset": "studio/dip", "args": { "color": "#000000" } }, "filter": { "preset": "studio/film", "args": { "grain": 0.02 } } } } }"##,
            #"{ "format": { "size": { "fit": "content" } }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#,
            #"{ "format": { "size": { "fit": "content", "margin": 0 } }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#,
            #"{ "format": { "size": { "fit": "content", "margin": [8, 16] } }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#,
            #"{ "format": { "size": { "fit": "content", "margin": [1, 2, 3, 4] } }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#
        ]
    )
    func acceptsEveryForm(body: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a choice written as an object takes both sides, or a preset with another key beside it",
        arguments: [
            (#"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "animation": { "entrance": "frames/pop" } } ] }"#, #"clips[0].animation (animation choice): missing key "exit""#),
            (#"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "animation": { "exit": "frames/fade" } } ] }"#, #"clips[0].animation (animation choice): missing key "entrance""#),
            (#"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "animation": { "preset": "frames/pop" } } ] }"#, #"clips[0].animation (animation choice): needs one of args, by, stagger, order"#),
            (#"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "animation": { "entrance": { "preset": "frames/pop" }, "exit": "none" } } ] }"#, #"clips[0].animation.entrance (animation choice): missing key "args""#),
            (#"{ "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "animation": { "preset": "frames/pop", "args": {}, "seconds": 1 } } ] }"#, #"clips[0].animation (animation choice): unknown key "seconds". Allowed: preset, args, by, stagger, order"#),
            (#"{ "clips": [ { "kind": "title", "text": "a", "style": "title", "animation": { "preset": "frames/pop", "by": "word", "stagger": -0.1 } } ] }"#, #"clips[0].animation.stagger (animation choice): -0.1 is not 0 or more"#),
            (#"{ "theme": { "defaults": { "animation": { "shape": { "preset": "frames/pop", "by": "word" } } } } }"#, #"theme.defaults.animation.shape (animation choice): unknown key "by". Allowed: preset, args"#),
            (#"{ "clips": [ { "kind": "title", "text": "a", "style": "title", "animation": { "entrance": "frames/pop", "exit": "none", "stagger": -0.1 } } ] }"#, #"clips[0].animation.stagger (animation choice): -0.1 is not 0 or more"#),
            (#"{ "clips": [ { "kind": "title", "text": "a", "style": "title", "animation": { "entrance": "frames/pop", "exit": "none", "by": "word", "seconds": 1 } } ] }"#, #"clips[0].animation (animation choice): unknown key "seconds". Allowed: entrance, exit, by, stagger, order"#),
            (#"{ "clips": [ { "kind": "title", "text": "a", "style": "title", "animation": { "preset": "frames/pop", "by": "word", "order": "inward" } } ] }"#, #"clips[0].animation.order (animation choice): unknown value "inward". Allowed: forward, backward, center, edges, random"#),
            (#"{ "clips": [ { "kind": "title", "text": "a", "style": "title", "animation": { "entrance": "frames/pop", "exit": "none", "by": "word", "order": "inward" } } ] }"#, #"clips[0].animation.order (animation choice): unknown value "inward". Allowed: forward, backward, center, edges, random"#),
            (#"{ "theme": { "defaults": { "animation": { "title": { "title": { "preset": "frames/pop", "by": "word", "order": "Center" } } } } } }"#, #"theme.defaults.animation.title.title.order (animation choice): unknown value "Center". Allowed: forward, backward, center, edges, random"#),
            (#"{ "theme": { "defaults": { "animation": { "shape": { "entrance": "frames/pop", "exit": "none", "by": "word" } } } } }"#, #"theme.defaults.animation.shape (animation choice): unknown key "by". Allowed: entrance, exit"#),
            (#"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "transition": { "preset": "frames/push-up" } } ] }"#, #"storyline[0].transition (transition choice): needs one of seconds, args"#),
            (#"{ "theme": { "defaults": { "transition": { "preset": "frames/push-up" } } } }"#, #"theme.defaults.transition (transition choice): needs one of seconds, args"#),
            (#"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": { "preset": "frames/warm" } } ] }"#, #"storyline[0].filter (filter choice): needs one of args, mix"#),
            (#"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": [] } ] }"#, #"storyline[0].filter (filter choice): a filter list holds at least one entry"#),
            (#"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "filter": ["frames/warm", "none"] } ] }"#, #"storyline[0].filter[1] (filter choice): "none" turns the filter off, so it is written alone and never in a list"#)
        ]
    )
    func requiresChoiceKeys(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("an ease on a keyframe that no later keyframe follows for any of its properties stops at check")
    func refusesUnfollowedEase() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [
              { "kind": "media", "media": "/abs/log.png", "at": [0, 6],
                "keyframes": [ { "at": 3, "position": [600, 500] }, { "at": 4, "position": [330, 900], "scale": 1.5, "ease": "ease-in" } ] }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"clips[0].keyframes[1] (keyframe): "ease" shapes no span, since no later keyframe names position, scale"#)
    }

    @Test("a spring ease is taken on a keyframe with a bounce greater than -1 and less than 1")
    func acceptsSpringEase() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [
              { "kind": "media", "media": "/abs/log.png", "at": [0, 6],
                "keyframes": [ { "at": 3, "scale": 1, "ease": { "spring": { "bounce": 0.99 } } }, { "at": 4, "scale": 1.5 } ] }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a spring ease with a bounce outside its range or another key stops where it is written",
        arguments: [
            (#"{ "spring": { "bounce": 1 } }"#, "clips[0].keyframes[0].ease.spring.bounce (spring): 1 is not above -1 and below 1"),
            (#"{ "spring": { "bounce": -1 } }"#, "clips[0].keyframes[0].ease.spring.bounce (spring): -1 is not above -1 and below 1"),
            (#"{ "spring": { "bounce": "0.5" } }"#, #"clips[0].keyframes[0].ease.spring.bounce (spring): expected a number above -1 and below 1, found "0.5""#),
            (#"{ "spring": { "stiffness": 100 } }"#, #"clips[0].keyframes[0].ease.spring (spring): unknown key "stiffness". Allowed: bounce"#),
            (#"{ "bounce": 0.5 }"#, #"clips[0].keyframes[0].ease (spring ease): unknown key "bounce". Allowed: spring"#)
        ]
    )
    func refusesBrokenSpring(
        ease: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [
              { "kind": "media", "media": "/abs/log.png", "at": [0, 6],
                "keyframes": [ { "at": 3, "scale": 1, "ease": \#(ease) }, { "at": 4, "scale": 1.5 } ] }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a document whose kind is not sequence stops", arguments: ["image", "layout", "movie"])
    func refusesKindOtherThanSequence(kind: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "\#(kind)", "storyline": [] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"kind (document): unknown value "\#(kind)". Allowed: sequence"#)
    }

    @Test("a document without a kind stops")
    func refusesMissingKind() throws {
        // Given
        let document = try Fixture.json(#"{ "storyline": [] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"top level (document): missing key "kind""#)
    }

    @Test(
        "a rate of 0 or less stops where it is written",
        arguments: [
            (
                #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "imageSequence": "/abs/frames", "fps": 0 } } ] }"#,
                "storyline[0].media.fps (image sequence): 0 is not above 0"
            ),
            (
                #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "imageSequence": "/abs/frames", "fps": -24 } } ] }"#,
                "storyline[0].media.fps (image sequence): -24 is not above 0"
            ),
            (
                #"{ "kind": "sequence", "format": { "fps": 0 }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }"#,
                "format.fps (format): 0 is not above 0"
            )
        ]
    )
    func refusesNonPositiveRate(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(body)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a whole number is one that fits an integer exactly")
    func refusesIntegerOutOfRange() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "title", "text": "a", "style": "headline", "lane": 1e20 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "clips[0].lane (title): expected a whole number, found 1e+20")
    }

    @Test("a transition choice of 0 seconds or less stops where it is written")
    func refusesNonPositiveTransition() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "kind": "solid", "color": "#000000", "duration": 2 }, { "kind": "solid", "color": "#FFFFFF", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 0 } }
            ] }
            """##)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "storyline[1].transition.seconds (transition choice): 0 is not above 0")
    }

    @Test(
        "a media clip's width and height are above 0",
        arguments: [
            (#""width": 0"#, "clips[0].width (image): 0 is not above 0"),
            (#""width": -300"#, "clips[0].width (image): -300 is not above 0"),
            (#""height": 0"#, "clips[0].height (image): 0 is not above 0"),
            (#""width": 300, "height": -1"#, "clips[0].height (image): -1 is not above 0")
        ]
    )
    func refusesEmptyMediaBox(
        keys: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], \#(keys) } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a title's wrapping width is above 0")
    func refusesEmptyTitleWidth() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "title", "text": "Hi", "style": "title", "at": [0, 1], "position": [0, 0], "width": 0 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "clips[0].width (title): 0 is not above 0")
    }

    @Test("a title is a list of runs, each its text with a style or without one")
    func acceptsTitleRuns() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [ { "kind": "title", "text": [ { "text": "Ana Ruiz", "style": "name" }, { "text": "\nDirector" } ],
              "style": "role", "at": [0, 1] } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a list of runs holds at least one run, and a run is an object of its text and style with its text",
        arguments: [
            (#"[]"#, "clips[0].text (title): a list of runs holds at least one run, since a title without one has nothing to show"),
            (#"[ "Ana" ]"#, #"clips[0].text[0] (title): expected an object (run), found "Ana""#),
            (##"[ { "text": "Ana", "color": "#FFFFFF" } ]"##, #"clips[0].text[0] (run): unknown key "color". Allowed: text, style"#),
            (#"[ { "style": "name" } ]"#, #"clips[0].text[0] (run): missing key "text""#),
            (#"[ { "text": 3 } ]"#, "clips[0].text[0].text (run): expected a string, found 3")
        ]
    )
    func refusesMalformedRuns(
        title: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [ { "kind": "title", "text": \#(title), "style": "role", "at": [0, 1] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a media clip's radius of 0 leaves square corners")
    func admitsZeroRadius() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "radius": 0 } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a stroke and a border take each align, and a border also true, false, a colour and an object of some of its keys", arguments: StrokeAlign.allCases)
    func acceptsAlign(align: StrokeAlign) throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "border": { "align": "\##(align.rawValue)" },
                                             "shapes": { "frame": { "stroke": { "width": 2, "align": "\##(align.rawValue)" } } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "border": { "align": "\##(align.rawValue)" } } ],
              "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "align": "\##(align.rawValue)" }, "at": [0, 1] },
                         { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "border": { "width": 2, "color": "#FF0000", "align": "\##(align.rawValue)" } },
                         { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "border": true },
                         { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "border": false },
                         { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "border": "#FF0000" } ] }
            """##)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "an align other than inside, center or outside stops, naming its place",
        arguments: [
            (
                #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "align": "middle" } } ] }"#,
                #"clips[0].stroke.align (stroke): unknown value "middle". Allowed: inside, center, outside"#
            ),
            (
                #"{ "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "border": { "align": "middle" } } ] }"#,
                #"clips[0].border.align (border): unknown value "middle". Allowed: inside, center, outside"#
            ),
            (
                #"{ "theme": { "border": { "align": "middle" } } }"#,
                #"theme.border.align (border): unknown value "middle". Allowed: inside, center, outside"#
            )
        ]
    )
    func refusesUnknownAlign(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a mask is taken and keyframed by a storyline clip with media, a media clip, a title, every shape kind and an adjustment",
        arguments: [
            ("storyline", #""kind": "media", "media": "/abs/run.mp4""#),
            ("storyline", #""kind": "media", "media": "/abs/card.png", "duration": 2"#),
            ("clips", #""kind": "media", "media": "/abs/log.png", "at": [0, 2]"#),
            ("clips", #""kind": "title", "text": "a", "style": "headline", "at": [0, 2]"#),
            ("clips", #""kind": "rect", "area": [0, 0, 100, 100], "at": [0, 2]"#),
            ("clips", #""kind": "rect", "width": 100, "height": 50, "at": [0, 2]"#),
            ("clips", #""kind": "ellipse", "area": [0, 0, 100, 100], "at": [0, 2]"#),
            ("clips", #""kind": "path", "points": [[0, 0], [100, 100]], "at": [0, 2]"#),
            ("clips", #""kind": "adjustment", "adjust": "frames/vivid", "at": [0, 2]"#)
        ]
    )
    func acceptsMask(
        list: String,
        keys: String
    ) throws {
        // Given
        let masks = #"""
            [ { "kind": "rect", "area": [0, 0, 10, 10], "radius": 2, "feather": 1, "invert": true },
              { "kind": "ellipse", "width": 10, "height": 10, "position": [5, 5], "mode": "subtract" },
              { "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "mode": "intersect" } ]
            """#
        let written = try Fixture.json(#"{ "kind": "sequence", "\#(list)": [ { \#(keys), "mask": \#(masks) } ] }"#)
        let keyframed = try Fixture.json(#"""
            { "kind": "sequence", "\#(list)": [ { \#(keys), "mask": { "kind": "ellipse" }, "keyframes": [
                { "at": 0, "mask": { "area": [0, 0, 10, 10] } },
                { "at": 1, "mask": { "area": [10, 10, 20, 20], "feather": 4 } } ] } ] }
            """#)

        // When, Then
        try sut.check(document: written)
        try sut.check(document: keyframed)
    }

    @Test("an adjustment clip takes every key of a clip with a picture, a blend mode among them")
    func acceptsAdjustmentPictureKeys() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [ { "id": "shot", "kind": "media", "media": "/abs/run.mp4",
                "connected": [ { "id": "matte", "kind": "title", "text": "a", "style": "headline", "at": [0, 2] },
                               { "id": "grade", "metadata": { "by": "x" }, "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 2],
                                 "lane": 2, "parent": "shot", "blend": "screen",
                                 "mask": { "kind": "rect", "area": [0, 0, 10, 10] },
                                 "trackMatte": { "clip": "matte", "mode": "alpha" }, "track": { "time": 0, "frames": [] },
                                 "animation": "frames/fade", "keyframes": [ { "at": 0, "opacity": 1 } ] },
                               { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 2], "opacity": 0.5 } ] } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a mask on a clip with no picture stops as an unknown key, and an adjustment's area is gone",
        arguments: [
            (
                "clips",
                #"{ "kind": "media", "media": "/abs/bgm.m4a", "mask": { "kind": "rect", "area": [0, 0, 10, 10] } }"#,
                #"clips[0] (audio): unknown key "mask". Allowed: "#
            ),
            (
                "storyline",
                ##"{ "kind": "solid", "color": "#000000", "duration": 2, "mask": { "kind": "rect", "area": [0, 0, 10, 10] } }"##,
                #"storyline[0] (solid): unknown key "mask". Allowed: "#
            ),
            (
                "clips",
                #"{ "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 1], "area": [0, 0, 10, 10] }"#,
                #"clips[0] (adjustment): unknown key "area". Allowed: "#
            )
        ]
    )
    func refusesMaskWithoutPicture(
        list: String,
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "\#(list)": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a mask takes only the keys of its kind, and a rect or ellipse exactly one of an area and a whole box",
        arguments: [
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "points": [[0, 0], [10, 0], [5, 10]] }"#, #"clips[0].mask (rect mask): unknown key "points""#),
            (#"{ "kind": "ellipse", "area": [0, 0, 10, 10], "radius": 2 }"#, #"clips[0].mask (ellipse mask): unknown key "radius""#),
            (#"{ "kind": "ellipse", "area": [0, 0, 10, 10], "points": [[0, 0], [10, 0], [5, 10]] }"#, #"clips[0].mask (ellipse mask): unknown key "points""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "area": [0, 0, 10, 10] }"#, #"clips[0].mask (path mask): unknown key "area""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "width": 10 }"#, #"clips[0].mask (path mask): unknown key "width""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "height": 10 }"#, #"clips[0].mask (path mask): unknown key "height""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "position": [5, 5] }"#, #"clips[0].mask (path mask): unknown key "position""#),
            (#"{ "kind": "path", "points": [[0, 0], [10, 0], [5, 10]], "radius": 2 }"#, #"clips[0].mask (path mask): unknown key "radius""#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "outset": 2 }"#, #"clips[0].mask (rect mask): unknown key "outset""#),
            (#"[ { "kind": "rect", "area": [0, 0, 10, 10] }, { "kind": "ellipse", "area": [0, 0, 10, 10], "radius": 2 } ]"#, #"clips[0].mask[1] (ellipse mask): unknown key "radius""#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "width": 10, "height": 10 }"#, #"clips[0].mask (rect mask): takes only one of "area", "width", "height""#),
            (#"{ "kind": "ellipse" }"#, "clips[0].mask (ellipse mask): needs one of area, width, height, position"),
            (#"{ "kind": "rect", "height": 10, "position": [5, 5] }"#, #"clips[0].mask (rect mask): missing key "width""#),
            (#"{ "kind": "rect", "width": 10, "position": [5, 5] }"#, #"clips[0].mask (rect mask): missing key "height""#),
            (#"{ "kind": "ellipse", "width": 10, "height": 10 }"#, #"clips[0].mask (ellipse mask): missing key "position""#),
            (#"{ "kind": "path" }"#, #"clips[0].mask (path mask): missing key "points""#),
            (#"{ "kind": "path", "points": [[0, 0]] }"#, "clips[0].mask.points (path mask): expected a list of at least two vertices, each [x, y] or {vertex, inTangent, outTangent}"),
            (#"{ "area": [0, 0, 10, 10] }"#, #"clips[0].mask (mask): missing key "kind""#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10] }"#, #"clips[0].mask (mask): missing key "kind""#),
            (#"{ "kind": "rect", "shape": "rect", "area": [0, 0, 10, 10] }"#, #"clips[0].mask (rect mask): unknown key "shape""#),
            (#"{ "kind": "star", "area": [0, 0, 10, 10] }"#, #"clips[0].mask.kind (mask): unknown value "star". Allowed: rect, ellipse, path"#),
            (#"{ "kind": "rect", "area": [0, 0, 10, 10], "mode": "multiply" }"#, #"clips[0].mask.mode (rect mask): unknown value "multiply". Allowed: add, subtract, intersect"#),
            ("[]", "clips[0].mask (adjustment): a mask list holds at least one mask, and a clip without masks writes no mask"),
            ("true", "clips[0].mask (adjustment): expected a mask or a list of masks, found true")
        ]
    )
    func refusesMaskKeys(
        mask: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 1], "mask": \#(mask) } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a mask's geometry is given by the clip's mask and its keyframes together",
        arguments: [
            (#"{ "kind": "rect" }"#, #"[ { "at": 0, "mask": { "area": [0, 0, 10, 10] } }, { "at": 1, "mask": { "area": [0, 0, 20, 20] } } ]"#),
            (#"{ "kind": "ellipse", "width": 10 }"#, #"[ { "at": 0, "mask": { "height": 10, "position": [5, 5] } }, { "at": 1, "mask": { "width": 20 } } ]"#),
            (#"{ "kind": "path" }"#, #"[ { "at": 0, "mask": { "points": [[0, 0], [10, 0], [5, 10]] } } ]"#),
            (
                #"[ { "kind": "rect", "area": [0, 0, 10, 10] }, { "kind": "path" } ]"#,
                #"[ { "at": 0, "mask": [ { "radius": 2 }, { "points": [[0, 0], [10, 0], [5, 10]] } ] } ]"#
            )
        ]
    )
    func acceptsMaskGeometryInKeyframes(
        mask: String,
        keyframes: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [ { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 2], "mask": \#(mask), "keyframes": \#(keyframes) } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a mask's geometry missing from the clip's mask and its keyframes stops at the clip's mask, and a keyframe's mask takes its static mask's keys",
        arguments: [
            (
                #"{ "kind": "rect" }"#,
                #"[ { "at": 0, "mask": { "feather": 2 } } ]"#,
                "clips[0].mask (rect mask): needs one of area, width, height, position"
            ),
            (
                #"[ { "kind": "rect", "area": [0, 0, 10, 10] }, { "kind": "ellipse", "width": 10 } ]"#,
                #"[ { "at": 0, "mask": [ { }, { "height": 10 } ] } ]"#,
                #"clips[0].mask[1] (ellipse mask): missing key "position""#
            ),
            (
                #"{ "kind": "ellipse", "area": [0, 0, 10, 10] }"#,
                #"[ { "at": 0, "mask": { "radius": 2 } } ]"#,
                #"clips[0].keyframes[0].mask (ellipse mask): unknown key "radius""#
            ),
            (
                #"{ "kind": "path" }"#,
                #"[ { "at": 0, "mask": { "points": [[0, 0]] } } ]"#,
                "clips[0].keyframes[0].mask.points (mask): expected a list of at least two vertices, each [x, y] or {vertex, inTangent, outTangent}"
            )
        ]
    )
    func refusesMaskGeometryInKeyframes(
        mask: String,
        keyframes: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [ { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 2], "mask": \#(mask), "keyframes": \#(keyframes) } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a track matte is taken by a storyline clip with media, a media clip, a title, every shape kind and an adjustment",
        arguments: [
            ("storyline", #""kind": "media", "media": "/abs/run.mp4""#),
            ("storyline", #""kind": "media", "media": "/abs/card.png", "duration": 2"#),
            ("clips", #""kind": "media", "media": "/abs/log.png", "at": [0, 2]"#),
            ("clips", #""kind": "title", "text": "a", "style": "headline", "at": [0, 2]"#),
            ("clips", #""kind": "rect", "area": [0, 0, 100, 100], "at": [0, 2]"#),
            ("clips", #""kind": "ellipse", "width": 100, "height": 50, "at": [0, 2]"#),
            ("clips", #""kind": "path", "points": [[0, 0], [100, 100]], "at": [0, 2]"#),
            ("clips", #""kind": "adjustment", "adjust": "frames/vivid", "at": [0, 2]"#)
        ]
    )
    func acceptsTrackMatte(
        list: String,
        keys: String
    ) throws {
        // Given
        let alpha = try Fixture.json(#"""
            { "kind": "sequence", "\#(list)": [ { \#(keys), "trackMatte": { "clip": "matte", "mode": "alpha" } } ] }
            """#)
        let luma = try Fixture.json(#"""
            { "kind": "sequence", "\#(list)": [ { \#(keys), "trackMatte": { "clip": "matte", "mode": "luma", "invert": true } } ] }
            """#)

        // When, Then
        try sut.check(document: alpha)
        try sut.check(document: luma)
    }

    @Test(
        "a track matte on a clip with no picture stops as an unknown key, and it is not keyframable",
        arguments: [
            (
                "clips",
                #"{ "kind": "media", "media": "/abs/bgm.m4a", "trackMatte": { "clip": "matte", "mode": "alpha" } }"#,
                #"clips[0] (audio): unknown key "trackMatte". Allowed: "#
            ),
            (
                "storyline",
                ##"{ "kind": "solid", "color": "#000000", "duration": 2, "trackMatte": { "clip": "matte", "mode": "alpha" } }"##,
                #"storyline[0] (solid): unknown key "trackMatte". Allowed: "#
            ),
            (
                "clips",
                #"{ "kind": "title", "text": "a", "style": "headline", "keyframes": [ { "at": 1, "trackMatte": { "clip": "matte", "mode": "alpha" } } ] }"#,
                #"clips[0].keyframes[0] (keyframe): unknown key "trackMatte". Allowed: "#
            )
        ]
    )
    func refusesTrackMatteWithoutPicture(
        list: String,
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "\#(list)": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a track matte needs its clip and mode, takes only clip, mode and invert, and its mode is alpha or luma",
        arguments: [
            (#"{ "mode": "alpha" }"#, #"clips[0].trackMatte (track matte): missing key "clip""#),
            (#"{ "clip": "matte" }"#, #"clips[0].trackMatte (track matte): missing key "mode""#),
            (#"{ "clip": "matte", "mode": "alpha", "feather": 2 }"#, #"clips[0].trackMatte (track matte): unknown key "feather""#),
            (#"{ "clip": "matte", "mode": "red" }"#, #"clips[0].trackMatte.mode (track matte): unknown value "red". Allowed: alpha, luma"#),
            (#"{ "clip": "matte", "mode": "alpha", "invert": 1 }"#, "clips[0].trackMatte.invert (track matte): expected true or false, found 1"),
            (#""matte""#, #"clips[0].trackMatte (title): expected an object (track matte), found "matte""#)
        ]
    )
    func refusesTrackMatteKeys(
        matte: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [ { "kind": "title", "text": "a", "style": "headline", "at": [0, 1], "trackMatte": \#(matte) } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }
}
