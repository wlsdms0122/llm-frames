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
              "theme": { "defaults": { "transition": "frames/push-up", "filter": "frames/vivid", "animation": { "title": { "subtitle": "frames/pop" }, "shape": "frames/draw" } } },
              "storyline": [
                { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "volume": 0,
                  "keyframes": [ { "at": 2, "crop": { "scale": 1 } }, { "at": 8, "crop": { "scale": 1.08 } } ],
                  "connected": [ { "at": [2, 8], "title": "**Emphasis** subtitle", "style": "subtitle" } ] },
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
                { "at": [0, 30], "title": "Top title\n**emphasis**", "style": "headline", "lane": 2 },
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
        #expect(error?.description == #"storyline[2].connected[0] (path): unknown key "anim". Allowed: id, metadata, at, lane, parent, opacity, animation, keyframes, track, blend, mask, shape, style, anchor, position, scale, rotation, fill, stroke, trim, shadow, points, closed"#)
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
            (#"{ "shape": "rect", "area": [0, 0, 10, 10], "stroke": { "color": "accent" } }"#, #"clips[0].stroke (stroke): missing key "width""#),
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
            (#"{ "shape": "path", "points": [[0, 0], [1, 1]], "keyframes": [ { "at": 1, "area": [0, 0, 1, 1] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "area". Allowed: at, ease, points, position, scale, rotation, opacity, trim, mask"#),
            (#"{ "shape": "ellipse", "keyframes": [ { "at": 1, "radius": 2 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "radius". Allowed: at, ease, area, width, height, position, scale, rotation, opacity, trim, mask"#),
            (#"{ "title": "a", "style": "headline", "keyframes": [ { "at": 1, "crop": [0, 0, 1, 1] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "crop". Allowed: at, ease, position, scale, rotation, opacity, mask"#),
            (#"{ "media": "/abs/bgm.m4a", "keyframes": [ { "at": 1, "opacity": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "opacity". Allowed: at, ease, volume"#),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1, "volume": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "volume". Allowed: at, ease, position, scale, rotation, opacity, crop, mask"#),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1 } ] }"#, "clips[0].keyframes[0] (keyframe): needs one of position, scale, rotation, opacity, crop, mask"),
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
        "a storyline clip takes no placement and no parent, a solid takes a transition only, and masks and track mattes are not taken yet",
        arguments: [
            (
                #"{ "media": "/abs/run.mp4", "parent": "intro" }"#,
                #"storyline[0] (video): unknown key "parent". Allowed: id, metadata, media, in, track, out, speed, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, radius, border, shadow, volume, fadeIn, fadeOut, keyframes, connected"#
            ),
            (
                #"{ "media": "/abs/card.png", "duration": 2, "placement": "top" }"#,
                #"storyline[0] (image): unknown key "placement". Allowed: id, metadata, media, duration, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, radius, border, shadow, keyframes, connected"#
            ),
            (
                ##"{ "solid": "#FF0000", "duration": 2, "scale": 2 }"##,
                #"storyline[0] (solid): unknown key "scale". Allowed: id, metadata, solid, duration, transition, connected"#
            ),
            (
                #"{ "media": "/abs/card.png", "duration": 2, "trackMatte": { "clip": "matte" } }"#,
                #"storyline[0] (image): unknown key "trackMatte". Allowed: id, metadata, media, duration, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, radius, border, shadow, keyframes, connected"#
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
        "a choice written as an object takes both of its keys",
        arguments: [
            (#"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "animation": { "entrance": "frames/pop" } } ] }"#, #"clips[0].animation (animation choice): missing key "exit""#),
            (#"{ "clips": [ { "shape": "rect", "stroke": { "width": 8 }, "animation": { "exit": "frames/fade" } } ] }"#, #"clips[0].animation (animation choice): missing key "entrance""#),
            (#"{ "storyline": [ { "media": "/abs/run.mp4", "transition": { "preset": "frames/push-up" } } ] }"#, #"storyline[0].transition (transition choice): missing key "seconds""#),
            (#"{ "theme": { "defaults": { "transition": { "preset": "frames/push-up" } } } }"#, #"theme.defaults.transition (transition choice): missing key "seconds""#)
        ]
    )
    func requiresBothChoiceKeys(
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

    @Test("a media clip's radius of 0 leaves square corners")
    func admitsZeroRadius() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "media": "/abs/card.png", "at": [0, 1], "radius": 0 } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }
}
