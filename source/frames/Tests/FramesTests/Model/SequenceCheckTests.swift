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
                { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "volume": 0,
                  "keyframes": [ { "at": 2, "crop": { "scale": 1 } }, { "at": 8, "crop": { "scale": 1.08 } } ],
                  "connected": [ { "at": [2, 8], "title": "Subtitle", "style": "subtitle" } ] },
                { "media": "/abs/run.mp4", "in": 17.5, "out": 23, "transition": "frames/flash", "volume": 0,
                  "keyframes": [ { "at": 18, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 19, "crop": { "from": "Enter your password", "to": "3" } } ],
                  "connected": [ { "at": [19, 22], "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Sent" }, "animation": "frames/stamp" },
                                 { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Account 110-" }, "track": true } ] },
                { "media": "/abs/card.png", "duration": 2.5,
                  "transition": { "preset": "frames/wipe-right", "seconds": 0.5 },
                  "connected": [ { "shape": "rect", "stroke": { "width": 8 },
                                   "keyframes": [ { "at": 1.2, "area": { "text": "First line" } }, { "at": 1.65, "area": { "text": "Second line" } } ] } ] }
              ],
              "clips": [
                { "at": [0, 30], "title": "Top title\nSecond line", "style": "headline", "lane": 2 },
                { "at": [1, 6], "media": "/abs/log.png", "width": 420, "radius": 24, "shadow": true,
                  "animation": { "entrance": "frames/pop", "exit": "frames/fade" }, "lane": 5,
                  "keyframes": [ { "at": 3, "position": [600, 500], "ease": "ease-in-out" }, { "at": 4, "position": [330, 900], "scale": 1.5 } ] },
                { "at": [0, 4], "media": "/abs/light-leak.mov", "blend": "screen", "lane": 3 },
                { "media": "/abs/bgm.m4a", "volume": 0.3, "loop": true, "fadeOut": 1 },
                { "at": 1.0, "media": "/abs/ding.wav", "in": 0, "out": 1.5 }
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
              { "media": "/abs/run.mp4" }, { "media": "/abs/run.mp4" },
              { "media": "/abs/run.mp4", "connected": [ { "shape": "path", "points": [[0, 0], [10, 10]], "anim": "pop" } ] }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[2].connected[0] (path): unknown key "anim". Allowed: id, metadata, at, lane, parent, opacity, blend, mask, trackMatte, track, animation, keyframes, shape, style, position, anchor, fill, stroke, trim, shadow, scale, rotation, points, closed"#)
    }

    @Test(
        "a format takes no inset, in a document as in a compound clip",
        arguments: [
            (
                #"{ "kind": "sequence", "format": { "inset": [10, 10, 10, 10] }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
                #"format (format): unknown key "inset". Allowed: size, fps, background, conform"#
            ),
            (
                #"""
                { "kind": "sequence", "storyline": [ { "media": { "kind": "sequence", "format": { "size": [640, 480], "inset": [10, 10, 10, 10] },
                  "storyline": [ { "media": "/abs/run.mp4" } ] } } ] }
                """#,
                #"storyline[0].media.format (format): unknown key "inset". Allowed: size, fps, background, conform"#
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
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": "2" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].in (video): expected a number, found "2""#)
    }

    @Test("a number does not stand for a boolean")
    func refusesNumberForBool() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "media": "/abs/bgm.m4a", "loop": 1 } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error == .wrongType(place: Place(components: [.key("clips"), .index(0, id: nil), .key("loop")]), kind: "audio", expected: "true or false", found: "1"))
    }

    @Test("the first mistake in the file is the one reported")
    func stopsAtFirstMistake() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "speeed": 2, "fadein": 1 } ], "clip": [] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(#"storyline[0] (video): unknown key "speeed""#) == true)
    }

    @Test(
        "the media a clip holds picks its row of keys",
        arguments: [
            (#"{ "media": "/abs/card.png", "duration": 2, "in": 1 }"#, "storyline", #"storyline[0] (image): unknown key "in""#),
            (#"{ "media": "/abs/run.mp4", "duration": 2 }"#, "storyline", #"storyline[0] (video): unknown key "duration""#),
            (##"{ "solid": "#000000", "duration": 2, "crop": [0, 0, 1, 1] }"##, "storyline", #"storyline[0] (solid): unknown key "crop""#),
            (#"{ "media": "/abs/bgm.m4a", "lane": 2 }"#, "clips", #"clips[0] (audio): unknown key "lane""#),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "loop": true }"#, "clips", #"clips[0] (image): unknown key "loop""#),
            (#"{ "title": "a", "style": "headline", "crop": [0, 0, 1, 1] }"#, "clips", #"clips[0] (title): unknown key "crop""#),
            (#"{ "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 1, 1], "side": "left" }"#, "clips", #"clips[0] (rect): unknown key "side""#),
            (#"{ "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 1, 1], "label": "x" }"#, "clips", #"clips[0] (rect): unknown key "label""#),
            (#"{ "adjust": "frames/vivid", "label": "x" }"#, "clips", #"clips[0] (adjustment): unknown key "label""#),
            (#"{ "id": "a", "media": "/abs/run.mp4", "parent": "b" }"#, "storyline", #"storyline[0]#a (video): unknown key "parent""#),
            (##"{ "solid": "#000000", "duration": 2, "parent": "b" }"##, "storyline", #"storyline[0] (solid): unknown key "parent""#),
            (#"{ "media": "/abs/run.mp4", "placement": "top" }"#, "storyline", #"storyline[0] (video): unknown key "placement""#),
            (#"{ "media": "/abs/bgm.m4a", "parent": "b" }"#, "clips", #"clips[0] (audio): unknown key "parent""#)
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
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/clip", "in": 1, "out": 2 } ] }"#)
        let still = KeyChecker(mediaKinds: MediaKindTable(["/abs/clip": .image]))
        let video = KeyChecker(mediaKinds: MediaKindTable(["/abs/clip": .video]))

        // When, Then
        #expect(throws: ModelError.self) { try still.check(document: document) }
        try video.check(document: document)
    }

    @Test("media that is not there stops")
    func refusesMissingMedia() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/unknown.mov" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].media (storyline clip): media "/abs/unknown.mov" is not there"#)
    }

    @Test("a storyline clip whose media holds only sound stops")
    func refusesSoundOnStoryline() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/bgm.m4a" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix("storyline[0] (audio):") == true)
    }

    @Test(
        "a clip is exactly one kind, told apart by its keys",
        arguments: [
            (#"{ "storyline": [ { "duration": 2 } ] }"#, "storyline[0] (storyline clip): needs one of media, solid"),
            (#"{ "clips": [ { "at": [0, 1] } ] }"#, "clips[0] (clip): needs one of media, title, shape, adjust"),
            (#"{ "clips": [ { "title": "a", "shape": "rect", "stroke": { "width": 8 } } ] }"#, #"clips[0] (clip): takes only one of "title", "shape""#),
            (#"{ "storyline": [ { "title": "a", "style": "headline" } ] }"#, #"storyline[0] (storyline clip): unknown key "title". Allowed: media, solid"#),
            (##"{ "clips": [ { "solid": "#000000" } ] }"##, #"clips[0] (clip): unknown key "solid". Allowed: media, title, shape, adjust"#),
            (#"{ "clips": [ { "shape": "circle" } ] }"#, #"clips[0].shape (shape): unknown value "circle". Allowed: rect, ellipse, path"#)
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

    @Test("a title names its style")
    func requiresTitleStyle() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "title": "Hello", "at": [0, 1] } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"clips[0] (title): missing key "style""#)
    }

    @Test(
        "a key a shape kind does not take stops",
        arguments: [
            (#"{ "shape": "ellipse", "area": [0, 0, 10, 10], "radius": 4 }"#, #"clips[0] (ellipse): unknown key "radius""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 10]], "radius": 4 }"#, #"clips[0] (path): unknown key "radius""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 10]], "outset": 4 }"#, #"clips[0] (path): unknown key "outset""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 10]], "area": [0, 0, 10, 10] }"#, #"clips[0] (path): unknown key "area""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 10]], "width": 10 }"#, #"clips[0] (path): unknown key "width""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 10]], "height": 10 }"#, #"clips[0] (path): unknown key "height""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 10]], "placement": "top" }"#, #"clips[0] (path): unknown key "placement""#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "points": [[0, 0], [10, 10]] }"#, #"clips[0] (rect): unknown key "points""#),
            (#"{ "shape": "ellipse", "area": [0, 0, 10, 10], "closed": true }"#, #"clips[0] (ellipse): unknown key "closed""#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "color": "accent" }"#, #"clips[0] (rect): unknown key "color""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 10]], "keyframes": [ { "at": 0, "radius": 2 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "radius""#)
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
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "fill": true }"#, #"clips[0].fill (rect): expected "#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "stroke": true }"#, #"clips[0].stroke (rect): expected "#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 0 } }"#, #"clips[0].stroke.width (stroke): expected a number above 0, found 0"#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "join": "square" } }"#, #"clips[0].stroke.join (stroke): unknown value "square". Allowed: miter, round, bevel"#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "end": "dot" } }"#, #"clips[0].stroke.end (stroke): unknown value "dot". Allowed: none, arrow"#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "width": 2, "head": 8 } }"#, #"clips[0].stroke (stroke): unknown key "head""#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "fill": "accent", "trim": [0, 1.5] }"#, #"clips[0].trim[1] (rect): expected a list of 2 numbers, each from 0 to 1, found 1.5"#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "fill": "accent", "trim": [0.5] }"#, #"clips[0].trim (rect): expected a list of 2 numbers, each from 0 to 1"#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "fill": "accent", "shadow": "soft" }"#, #"clips[0].shadow (rect): expected "#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "fill": "accent", "shadow": { "blur": 4 } }"#, #"clips[0].shadow (shadow): unknown key "blur""#),
            (#"{ "shape": "path", "points": [[0, 0]], "fill": "accent" }"#, #"clips[0].points (path): expected a list of at least two points"#),
            (#"{ "shape": "path", "points": [[0, 0], "top"], "fill": "accent" }"#, #"clips[0].points[1] (path): expected "#),
            (#"{ "shape": "path", "points": [[0, 0], [1, 1]], "closed": 1, "fill": "accent" }"#, #"clips[0].closed (path): expected "#)
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
        "a shape takes its appearance keys in every form they have",
        arguments: [
            #"{ "shape": "rect", "width": 100, "height": 50, "placement": "top", "radius": 8, "outset": -2, "fill": false, "stroke": { "color": "accent", "width": 4, "join": "miter", "cap": "square", "start": "arrow", "end": "none" }, "shadow": true }"#,
            ##"{ "shape": "ellipse", "area": [0, 0, 10, 10], "fill": "#FFFFFF80", "stroke": false, "trim": [0.25, 0], "shadow": { "radius": 4 } }"##,
            #"{ "shape": "path", "points": [[0, 0], { "area": [0, 0, 10, 10], "point": "center" }], "closed": true, "style": "outline", "shadow": false }"#,
            #"{ "shape": "path", "fill": "accent", "keyframes": [ { "at": 0, "points": [[0, 0], [2, 2]], "trim": [0, 0.5], "position": [1, 1], "scale": 2, "rotation": 90 } ] }"#,
            #"{ "shape": "rect", "fill": "accent", "keyframes": [ { "at": 0, "width": 10, "height": 20, "radius": 2, "area": [0, 0, 1, 1] } ] }"#
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
        let clip = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "media": "/abs/log.png", "at": [0, 1], "shadow": \#(shadow) } ] }"#)
        let storyline = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/log.png", "shadow": \#(shadow) } ] }"#)

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
              { "media": "/abs/log.png", "at": [0, 4], "scale": 1, "keyframes": [ { "at": 1, "scale": 2 } ] }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error == .staticAndKeyframed(place: Place(components: [.key("clips"), .index(0, id: nil)]), kind: "image", property: "scale"))
    }

    @Test(
        "a keyframe takes only the keyframable properties of its clip",
        arguments: [
            (#"{ "adjust": "frames/vivid", "keyframes": [ { "at": 1, "position": [0, 0] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "position". Allowed: at, ease, opacity, mask"#),
            (#"{ "shape": "path", "points": [[0, 0], [1, 1]], "keyframes": [ { "at": 1, "area": [0, 0, 1, 1] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "area". Allowed: at, ease, points, position, scale, rotation, opacity, trim, fill, stroke, shadow, mask"#),
            (#"{ "shape": "ellipse", "keyframes": [ { "at": 1, "radius": 2 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "radius". Allowed: at, ease, area, width, height, position, scale, rotation, opacity, trim, outset, fill, stroke, shadow, mask"#),
            (#"{ "title": "a", "style": "headline", "keyframes": [ { "at": 1, "crop": [0, 0, 1, 1] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "crop". Allowed: at, ease, position, scale, rotation, opacity, mask"#),
            (#"{ "media": "/abs/bgm.m4a", "keyframes": [ { "at": 1, "opacity": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "opacity". Allowed: at, ease, volume, pan"#),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1, "volume": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "volume". Allowed: at, ease, position, scale, rotation, opacity, crop, mask, radius, border, shadow"#),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1 } ] }"#, "clips[0].keyframes[0] (keyframe): needs one of position, scale, rotation, opacity, crop, mask, radius, border, shadow"),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "scale": 1 } ] }"#, #"clips[0].keyframes[0] (keyframe): missing key "at""#)
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
        let still = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/card.png", "keyframes": [ { "at": 0, "volume": 1 } ] } ] }"#)
        let video = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "keyframes": [ { "at": 0, "volume": 1 }, { "at": 1, "crop": { "scale": 2 } } ] } ] }"#)

        // When, Then
        #expect(throws: ModelError.self) { try sut.check(document: still) }
        try sut.check(document: video)
    }

    @Test("`pan` is keyframable on an audio clip, a connected video and a storyline video")
    func keyframesPan() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "media": "/abs/run.mp4", "pan": 0.2, "connected": [
                { "media": "/abs/run.mp4", "at": [0, 1], "keyframes": [ { "at": 0, "pan": -1 }, { "at": 1, "pan": 1 } ] }
              ], "keyframes": [] }
            ], "clips": [
              { "media": "/abs/bgm.m4a", "keyframes": [ { "at": 0, "pan": -0.5, "ease": "ease-in-out" }, { "at": 2, "pan": 0.5 } ] }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a `pan` outside -1 to 1 stops as a value of the wrong type")
    func refusesPanOutOfRange() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "media": "/abs/bgm.m4a", "pan": 1.5 } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "clips[0].pan (audio): expected a number from -1 to 1, found 1.5")
    }

    @Test("a still takes no `pan`, since it plays no sound")
    func refusesPanOnStill() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "media": "/abs/log.png", "at": [0, 1], "pan": 0 } ] }"#)

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
              { "media": "/abs/card.png", "duration": 2, "anchor": "top-left", "blend": "screen", "radius": 12, "border": true, "shadow": true,
                "keyframes": [ { "at": 0, "position": [0, 0], "scale": 1, "rotation": 0, "opacity": 1 }, { "at": 2, "position": [10, 0], "scale": 0.5, "rotation": 90, "opacity": 0 } ] },
              { "media": "/abs/run.mp4", "position": [540, 960], "scale": 0.5, "rotation": 10, "opacity": 0.8 }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a storyline clip takes no placement and no parent, and a solid takes a transition only",
        arguments: [
            (
                #"{ "media": "/abs/run.mp4", "parent": "intro" }"#,
                #"storyline[0] (video): unknown key "parent". Allowed: id, metadata, media, in, out, speed, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, trackMatte, track, radius, border, shadow, volume, pan, fadeIn, fadeOut, keyframes, connected"#
            ),
            (
                #"{ "media": "/abs/card.png", "duration": 2, "placement": "top" }"#,
                #"storyline[0] (image): unknown key "placement". Allowed: id, metadata, media, duration, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, trackMatte, radius, border, shadow, keyframes, connected"#
            ),
            (
                ##"{ "solid": "#FF0000", "duration": 2, "scale": 2 }"##,
                #"storyline[0] (solid): unknown key "scale". Allowed: id, metadata, solid, duration, transition, connected"#
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
        "a storyline solid takes no transform key, keyframed or not, so its transform is always the identity",
        arguments: [
            (#""anchor": "top-left""#, "anchor"),
            (#""position": [0, 0]"#, "position"),
            (#""scale": 2"#, "scale"),
            (#""rotation": 90"#, "rotation"),
            (#""keyframes": [ { "at": 0, "position": [0, 0] } ]"#, "keyframes")
        ]
    )
    func refusesSolidTransform(
        key: String,
        name: String
    ) throws {
        // Given
        let document = try Fixture.json(##"{ "kind": "sequence", "storyline": [ { "solid": "#FF0000", "duration": 2, \##(key) } ] }"##)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0] (solid): unknown key "\#(name)". Allowed: id, metadata, solid, duration, transition, connected"#)
    }

    @Test("an id is a string unique within its document, and a nested document has its own")
    func checksIdentifiers() throws {
        // Given
        let duplicate = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "id": "a", "title": "x", "style": "s" }, { "id": "a", "shape": "rect", "stroke": { "width": 8 } } ] }"#)
        let nested = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "id": "a", "media": { "kind": "sequence", "storyline": [ { "id": "a", "media": "/abs/run.mp4" } ] } }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: duplicate) }
        #expect(error?.description == #"clips[1]#a (rect): id "a" is already used at clips[0]#a"#)
        try sut.check(document: nested)
    }

    @Test("metadata is an object whose contents are not checked")
    func leavesMetadataUnchecked() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "shape": "rect", "metadata": { "by": "redactor", "anything": [1, { "param": "x" }] } } ] }"#)
        let notObject = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "shape": "rect", "metadata": "note" } ] }"#)

        // When, Then
        try sut.check(document: document)
        #expect(throws: ModelError.self) { try sut.check(document: notObject) }
    }

    @Test(
        "values of the wrong form stop",
        arguments: [
            #"{ "clips": [ { "title": "a", "style": "s", "at": 2 } ] }"#,
            #"{ "clips": [ { "title": "a", "style": "s", "parent": true, "position": [0, 0] } ] }"#,
            #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "parent": 1 } ] }"#,
            #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "lane": 1.5 } ] }"#,
            ##"{ "clips": [ { "shape": "rect", "fill": "#12345" } ] }"##,
            #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "blend": "add" } ] }"#,
            #"{ "clips": [ { "title": "a", "style": "s", "placement": "middle" } ] }"#,
            #"{ "clips": [ { "media": "/abs/log.png", "at": [0, 1], "border": false } ] }"#,
            #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "opacity": 1, "ease": "ease" } ] } ] }"#,
            #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "opacity": 1, "ease": [1.2, 0, 0.5, 1] } ] } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "transition": { "seconds": 1 } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "filter": ["frames/vivid", 2] } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "text": "a", "nth": "1" } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "from": "a" } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "middle": "a" } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "scale": 0 } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "scale": -1 } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "keyframes": [ { "at": 0, "crop": { "scale": 0 } } ] } ] }"#,
            #"{ "storyline": [ { "media": { "imageSequence": "/abs/frames" } } ] }"#,
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

    @Test(
        "an area written in a removed form, or with a size or padding it cannot take, stops where it is written",
        arguments: [
            (
                #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": "Total" } ] }"#,
                #"storyline[0].crop (video): expected an area or {scale}, found "Total""#
            ),
            (
                #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "band": { "text": "Total" } } } ] }"#,
                "storyline[0].crop (area): needs one of text, from"
            ),
            (
                #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 0, 10] } ] }"#,
                "clips[0].area[2] (rect): expected a number above 0, found 0"
            ),
            (
                #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "area": [0, 0, 10, -1] } ] } ] }"#,
                "clips[0].keyframes[0].area[3] (keyframe): expected a number above 0, found -1"
            ),
            (
                #"{ "storyline": [ { "media": "/abs/run.mp4", "track": { "text": "a", "padding": -1 } } ] }"#,
                "storyline[0].track.padding (text area): expected a number, 0 or more, found -1"
            ),
            (
                #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "from": "a", "to": "b", "toNth": -1 } } ] }"#,
                "storyline[0].crop.toNth (text range area): expected a whole number, 0 or more, found -1"
            ),
            (
                #"{ "clips": [ { "title": "a", "style": "s", "position": { "area": "Send", "point": "left" } } ] }"#,
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
            { "kind": "sequence", "format": { "size": \#(size) }, "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "every form the specification gives a value is taken",
        arguments: [
            #"{ "clips": [ { "media": "/abs/run.mp4", "at": 2 } ] }"#,
            #"{ "clips": [ { "media": "/abs/log.png", "at": [0, 1], "border": "accent", "conform": "fill", "anchor": "top-left" } ] }"#,
            #"{ "storyline": [ { "id": "run", "media": "/abs/run.mp4", "connected": [ { "title": "a", "style": "s", "parent": "run", "position": { "area": { "text": "Send" }, "point": "left" }, "anchor": "right" } ] } ] }"#,
            #"{ "clips": [ { "title": "a", "style": "s", "parent": "run", "position": { "area": { "text": "Send" }, "point": "left" } }, { "shape": "rect", "stroke": { "width": 8 }, "parent": "run", "area": { "text": "Send" } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "text": "a", "nth": 1, "padding": 40 }, "track": { "from": "a", "to": "b", "fromNth": 0, "toNth": 1 } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "from": "a", "to": "b", "padding": 0 }, "track": [0, 0, 0.5, 0.5] } ] }"#,
            #"{ "storyline": [ { "media": { "imageSequence": "/abs/frames", "fps": 30 }, "in": 0, "out": 2 } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "filter": ["frames/vivid", "pack/warm", "/abs/f.json"], "transition": "cut" } ] }"#,
            #"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "keyframes": [ { "at": 0, "opacity": 1, "ease": [0.25, 0.1, 0.25, 1] }, { "at": 1, "opacity": 0 } ] } ] }"#,
            #"{ "clips": [ { "shape": "path", "points": [[0, 0], [10, 10]], "stroke": { "width": 4, "end": "arrow" }, "animation": { "entrance": "frames/pop", "exit": "none" } } ] }"#,
            ##"{ "storyline": [ { "media": "/abs/run.mp4", "transition": { "preset": "studio/dip", "seconds": 1, "args": { "color": "#1B3A6B" } } } ] }"##,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "transition": { "preset": "studio/dip", "args": { "curve": "linear" } } } ] }"#,
            #"{ "clips": [ { "title": "a", "style": "s", "animation": { "preset": "studio/spring-in", "args": { "bounce": 0.4 } } } ] }"#,
            #"{ "clips": [ { "title": "a", "style": "s", "animation": { "entrance": { "preset": "studio/spring-in", "args": { "ease": { "spring": { "bounce": 0.4 } } } }, "exit": "frames/fade" } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "filter": { "preset": "studio/film", "args": { "grain": 0.02 } } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "filter": ["frames/warm", { "preset": "studio/film", "args": { "grain": 0.02 } }, { "preset": "studio/film", "args": { "grain": 0.04 } }] } ] }"#,
            ##"{ "theme": { "defaults": { "transition": { "preset": "studio/dip", "args": { "color": "#000000" } }, "filter": { "preset": "studio/film", "args": { "grain": 0.02 } } } } }"##,
            #"{ "format": { "size": { "fit": "content" } }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
            #"{ "format": { "size": { "fit": "content", "margin": 0 } }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
            #"{ "format": { "size": { "fit": "content", "margin": [8, 16] } }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
            #"{ "format": { "size": { "fit": "content", "margin": [1, 2, 3, 4] } }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#
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
            (#"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "animation": { "entrance": "frames/pop" } } ] }"#, #"clips[0].animation (animation choice): missing key "exit""#),
            (#"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "animation": { "exit": "frames/fade" } } ] }"#, #"clips[0].animation (animation choice): missing key "entrance""#),
            (#"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "animation": { "preset": "frames/pop" } } ] }"#, #"clips[0].animation (animation choice): missing key "args""#),
            (#"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "animation": { "entrance": { "preset": "frames/pop" }, "exit": "none" } } ] }"#, #"clips[0].animation.entrance (animation choice): missing key "args""#),
            (#"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "animation": { "preset": "frames/pop", "args": {}, "seconds": 1 } } ] }"#, #"clips[0].animation (animation choice): unknown key "seconds". Allowed: preset, args"#),
            (#"{ "storyline": [ { "media": "/abs/run.mp4", "transition": { "preset": "frames/push-up" } } ] }"#, #"storyline[0].transition (transition choice): needs one of seconds, args"#),
            (#"{ "theme": { "defaults": { "transition": { "preset": "frames/push-up" } } } }"#, #"theme.defaults.transition (transition choice): needs one of seconds, args"#),
            (#"{ "storyline": [ { "media": "/abs/run.mp4", "filter": { "preset": "frames/warm" } } ] }"#, #"storyline[0].filter (filter choice): missing key "args""#),
            (#"{ "storyline": [ { "media": "/abs/run.mp4", "filter": [] } ] }"#, #"storyline[0].filter (filter choice): a filter list holds at least one preset"#),
            (#"{ "storyline": [ { "media": "/abs/run.mp4", "filter": ["frames/warm", "none"] } ] }"#, #"storyline[0].filter[1] (filter choice): "none" turns the filter off, so it is written alone and never in a list"#)
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
              { "media": "/abs/log.png", "at": [0, 6],
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
              { "media": "/abs/log.png", "at": [0, 6],
                "keyframes": [ { "at": 3, "scale": 1, "ease": { "spring": { "bounce": 0.99 } } }, { "at": 4, "scale": 1.5 } ] }
            ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a spring ease with a bounce outside its range or another key stops where it is written",
        arguments: [
            (#"{ "spring": { "bounce": 1 } }"#, "clips[0].keyframes[0].ease.spring.bounce (spring): expected a number greater than -1 and less than 1, found 1"),
            (#"{ "spring": { "bounce": -1 } }"#, "clips[0].keyframes[0].ease.spring.bounce (spring): expected a number greater than -1 and less than 1, found -1"),
            (#"{ "spring": { "bounce": "0.5" } }"#, #"clips[0].keyframes[0].ease.spring.bounce (spring): expected a number greater than -1 and less than 1, found "0.5""#),
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
              { "media": "/abs/log.png", "at": [0, 6],
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
                #"{ "kind": "sequence", "storyline": [ { "media": { "imageSequence": "/abs/frames", "fps": 0 } } ] }"#,
                "storyline[0].media.fps (image sequence): expected a number above 0, found 0"
            ),
            (
                #"{ "kind": "sequence", "storyline": [ { "media": { "imageSequence": "/abs/frames", "fps": -24 } } ] }"#,
                "storyline[0].media.fps (image sequence): expected a number above 0, found -24"
            ),
            (
                #"{ "kind": "sequence", "format": { "fps": 0 }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
                "format.fps (format): expected a number above 0, found 0"
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
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "title": "a", "style": "headline", "lane": 1e20 } ] }
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
              { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 0 } }
            ] }
            """##)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "storyline[1].transition.seconds (transition choice): expected a number above 0, found 0")
    }

    @Test(
        "a media clip's width and height are above 0 and its radius 0 or more",
        arguments: [
            (#""width": 0"#, "clips[0].width (image): expected a number above 0, found 0"),
            (#""width": -300"#, "clips[0].width (image): expected a number above 0, found -300"),
            (#""height": 0"#, "clips[0].height (image): expected a number above 0, found 0"),
            (#""width": 300, "height": -1"#, "clips[0].height (image): expected a number above 0, found -1"),
            (#""radius": -8"#, "clips[0].radius (image): expected a number, 0 or more, found -8")
        ]
    )
    func refusesEmptyMediaBox(
        keys: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "media": "/abs/card.png", "at": [0, 1], \#(keys) } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a title's wrapping width is above 0")
    func refusesEmptyTitleWidth() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "title": "Hi", "style": "title", "at": [0, 1], "position": [0, 0], "width": 0 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "clips[0].width (title): expected a number above 0, found 0")
    }

    @Test("a title is a list of runs, each its text with a style or without one")
    func acceptsTitleRuns() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [ { "title": [ { "text": "Ana Ruiz", "style": "name" }, { "text": "\nDirector" } ],
              "style": "role", "at": [0, 1] } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a list of runs holds at least one run, and a run is an object of its text and style with its text",
        arguments: [
            (#"[]"#, "clips[0].title (title): a list of runs holds at least one run, since a title without one has nothing to show"),
            (#"[ "Ana" ]"#, #"clips[0].title[0] (title): expected an object (run), found "Ana""#),
            (##"[ { "text": "Ana", "color": "#FFFFFF" } ]"##, #"clips[0].title[0] (run): unknown key "color". Allowed: text, style"#),
            (#"[ { "style": "name" } ]"#, #"clips[0].title[0] (run): missing key "text""#),
            (#"[ { "text": 3 } ]"#, "clips[0].title[0].text (run): expected a string, found 3")
        ]
    )
    func refusesMalformedRuns(
        title: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "clips": [ { "title": \#(title), "style": "role", "at": [0, 1] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a media clip's radius of 0 leaves square corners")
    func admitsZeroRadius() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "media": "/abs/card.png", "at": [0, 1], "radius": 0 } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a mask is taken and keyframed by a storyline clip with media, a media clip, a title, every shape kind and an adjustment",
        arguments: [
            ("storyline", #""media": "/abs/run.mp4""#),
            ("storyline", #""media": "/abs/card.png", "duration": 2"#),
            ("clips", #""media": "/abs/log.png", "at": [0, 2]"#),
            ("clips", #""title": "a", "style": "headline", "at": [0, 2]"#),
            ("clips", #""shape": "rect", "area": [0, 0, 100, 100], "at": [0, 2]"#),
            ("clips", #""shape": "rect", "width": 100, "height": 50, "at": [0, 2]"#),
            ("clips", #""shape": "ellipse", "area": [0, 0, 100, 100], "at": [0, 2]"#),
            ("clips", #""shape": "path", "points": [[0, 0], [100, 100]], "at": [0, 2]"#),
            ("clips", #""adjust": "frames/vivid", "at": [0, 2]"#)
        ]
    )
    func acceptsMask(
        list: String,
        keys: String
    ) throws {
        // Given
        let masks = #"""
            [ { "shape": "rect", "area": [0, 0, 10, 10], "radius": 2, "feather": 1, "invert": true },
              { "shape": "ellipse", "width": 10, "height": 10, "position": [5, 5], "mode": "subtract" },
              { "shape": "path", "points": [[0, 0], [10, 0], [5, 10]], "mode": "intersect" } ]
            """#
        let written = try Fixture.json(#"{ "kind": "sequence", "\#(list)": [ { \#(keys), "mask": \#(masks) } ] }"#)
        let keyframed = try Fixture.json(#"""
            { "kind": "sequence", "\#(list)": [ { \#(keys), "keyframes": [
                { "at": 0, "mask": { "shape": "ellipse", "area": [0, 0, 10, 10] } },
                { "at": 1, "mask": { "shape": "ellipse", "area": [10, 10, 20, 20], "feather": 4 } } ] } ] }
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
              "storyline": [ { "id": "shot", "media": "/abs/run.mp4",
                "connected": [ { "id": "matte", "title": "a", "style": "headline", "at": [0, 2] },
                               { "id": "grade", "metadata": { "by": "x" }, "adjust": "frames/vivid", "at": [0, 2],
                                 "lane": 2, "parent": "shot", "blend": "screen",
                                 "mask": { "shape": "rect", "area": [0, 0, 10, 10] },
                                 "trackMatte": { "clip": "matte", "mode": "alpha" }, "track": true,
                                 "animation": "frames/fade", "keyframes": [ { "at": 0, "opacity": 1 } ] },
                               { "adjust": "frames/vivid", "at": [0, 2], "opacity": 0.5 } ] } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a mask on a clip with no picture stops as an unknown key, and an adjustment's area is gone",
        arguments: [
            (
                "clips",
                #"{ "media": "/abs/bgm.m4a", "mask": { "shape": "rect", "area": [0, 0, 10, 10] } }"#,
                #"clips[0] (audio): unknown key "mask". Allowed: "#
            ),
            (
                "storyline",
                ##"{ "solid": "#000000", "duration": 2, "mask": { "shape": "rect", "area": [0, 0, 10, 10] } }"##,
                #"storyline[0] (solid): unknown key "mask". Allowed: "#
            ),
            (
                "clips",
                #"{ "adjust": "frames/vivid", "at": [0, 1], "area": [0, 0, 10, 10] }"#,
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
        "a mask takes only the keys of its shape, and a rect or ellipse exactly one of an area and a whole box",
        arguments: [
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "points": [[0, 0], [10, 0], [5, 10]] }"#, #"clips[0].mask (rect mask): unknown key "points""#),
            (#"{ "shape": "ellipse", "area": [0, 0, 10, 10], "radius": 2 }"#, #"clips[0].mask (ellipse mask): unknown key "radius""#),
            (#"{ "shape": "ellipse", "area": [0, 0, 10, 10], "points": [[0, 0], [10, 0], [5, 10]] }"#, #"clips[0].mask (ellipse mask): unknown key "points""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 0], [5, 10]], "area": [0, 0, 10, 10] }"#, #"clips[0].mask (path mask): unknown key "area""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 0], [5, 10]], "width": 10 }"#, #"clips[0].mask (path mask): unknown key "width""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 0], [5, 10]], "height": 10 }"#, #"clips[0].mask (path mask): unknown key "height""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 0], [5, 10]], "position": [5, 5] }"#, #"clips[0].mask (path mask): unknown key "position""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 0], [5, 10]], "radius": 2 }"#, #"clips[0].mask (path mask): unknown key "radius""#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "outset": 2 }"#, #"clips[0].mask (rect mask): unknown key "outset""#),
            (#"[ { "shape": "rect", "area": [0, 0, 10, 10] }, { "shape": "ellipse", "area": [0, 0, 10, 10], "radius": 2 } ]"#, #"clips[0].mask[1] (ellipse mask): unknown key "radius""#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "width": 10, "height": 10 }"#, #"clips[0].mask (rect mask): takes only one of "area", "width", "height""#),
            (#"{ "shape": "ellipse" }"#, "clips[0].mask (ellipse mask): needs one of area, width, height, position"),
            (#"{ "shape": "rect", "height": 10, "position": [5, 5] }"#, #"clips[0].mask (rect mask): missing key "width""#),
            (#"{ "shape": "rect", "width": 10, "position": [5, 5] }"#, #"clips[0].mask (rect mask): missing key "height""#),
            (#"{ "shape": "ellipse", "width": 10, "height": 10 }"#, #"clips[0].mask (ellipse mask): missing key "position""#),
            (#"{ "shape": "path" }"#, #"clips[0].mask (path mask): missing key "points""#),
            (#"{ "shape": "path", "points": [[0, 0], [10, 0]] }"#, "clips[0].mask.points (path mask): a path mask is closed, so it runs through at least three points, found 2"),
            (#"{ "area": [0, 0, 10, 10] }"#, #"clips[0].mask (mask): missing key "shape""#),
            (#"{ "shape": "star", "area": [0, 0, 10, 10] }"#, #"clips[0].mask.shape (mask): unknown value "star". Allowed: rect, ellipse, path"#),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "feather": -1 }"#, "clips[0].mask.feather (rect mask): expected a number, 0 or more, found -1"),
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "mode": "multiply" }"#, #"clips[0].mask.mode (rect mask): unknown value "multiply". Allowed: add, subtract, intersect"#),
            (#"{ "shape": "rect", "width": 0, "height": 10, "position": [5, 5] }"#, "clips[0].mask.width (rect mask): expected a number above 0, found 0"),
            ("[]", "clips[0].mask (adjustment): a mask list holds at least one mask, and a clip without masks writes no mask"),
            ("true", "clips[0].mask (adjustment): expected a mask or a list of masks, found true")
        ]
    )
    func refusesMaskKeys(
        mask: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "adjust": "frames/vivid", "at": [0, 1], "mask": \#(mask) } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test(
        "a track matte is taken by a storyline clip with media, a media clip, a title, every shape kind and an adjustment",
        arguments: [
            ("storyline", #""media": "/abs/run.mp4""#),
            ("storyline", #""media": "/abs/card.png", "duration": 2"#),
            ("clips", #""media": "/abs/log.png", "at": [0, 2]"#),
            ("clips", #""title": "a", "style": "headline", "at": [0, 2]"#),
            ("clips", #""shape": "rect", "area": [0, 0, 100, 100], "at": [0, 2]"#),
            ("clips", #""shape": "ellipse", "width": 100, "height": 50, "at": [0, 2]"#),
            ("clips", #""shape": "path", "points": [[0, 0], [100, 100]], "at": [0, 2]"#),
            ("clips", #""adjust": "frames/vivid", "at": [0, 2]"#)
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
                #"{ "media": "/abs/bgm.m4a", "trackMatte": { "clip": "matte", "mode": "alpha" } }"#,
                #"clips[0] (audio): unknown key "trackMatte". Allowed: "#
            ),
            (
                "storyline",
                ##"{ "solid": "#000000", "duration": 2, "trackMatte": { "clip": "matte", "mode": "alpha" } }"##,
                #"storyline[0] (solid): unknown key "trackMatte". Allowed: "#
            ),
            (
                "clips",
                #"{ "title": "a", "style": "headline", "keyframes": [ { "at": 1, "trackMatte": { "clip": "matte", "mode": "alpha" } } ] }"#,
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
            { "kind": "sequence", "clips": [ { "title": "a", "style": "headline", "at": [0, 1], "trackMatte": \#(matte) } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }
}
