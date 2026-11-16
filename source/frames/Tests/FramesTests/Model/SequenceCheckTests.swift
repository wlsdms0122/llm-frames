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
              "format": { "size": [1080, 1920], "fps": 30, "background": "#000000", "inset": [420, 40, 120, 40], "conform": "fit" },
              "theme": { "defaults": { "transition": "push-up", "filter": "vivid", "animation": { "title": { "subtitle": "pop" }, "shape": "draw" } } },
              "storyline": [
                { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "volume": 0,
                  "keyframes": [ { "at": 2, "crop": { "scale": 1 } }, { "at": 8, "crop": { "scale": 1.08 } } ],
                  "connected": [ { "at": [2, 8], "title": "**Emphasis** subtitle", "style": "subtitle" } ] },
                { "media": "/abs/run.mp4", "in": 17.5, "out": 23, "transition": "flash", "volume": 0,
                  "keyframes": [ { "at": 18, "crop": { "scale": 1 }, "ease": "ease-in-out" }, { "at": 19, "crop": { "from": "Enter your password", "to": "3" } } ],
                  "connected": [ { "at": [19, 22], "shape": "box", "area": "Sent", "label": "done", "animation": "stamp" },
                                 { "shape": "box", "area": "Account 110-", "track": true, "label": "this account" } ] },
                { "media": { "kind": "image", "source": "/abs/card.png" }, "duration": 2.5,
                  "transition": { "preset": "wipe-right", "seconds": 0.5 },
                  "connected": [ { "shape": "box",
                                   "keyframes": [ { "at": 1.2, "area": "First line" }, { "at": 1.65, "area": "Second line" } ] } ] }
              ],
              "clips": [
                { "at": [0, 30], "title": "Top title\n**emphasis**", "style": "headline", "lane": 2 },
                { "at": [1, 6], "media": "/abs/log.png", "width": 420, "radius": 24, "shadow": true,
                  "animation": { "entrance": "pop", "exit": "fade" }, "lane": 5,
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
              { "media": "/abs/run.mp4", "connected": [ { "shape": "arrow", "area": "Send", "side": "left", "anim": "pop" } ] }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[2].connected[0] (arrow): unknown key "anim". Allowed: id, metadata, at, lane, opacity, animation, keyframes, shape, area, track, label, labelAnimation, color, blend, side"#)
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
            (#"{ "shape": "box", "area": [0, 0, 1, 1], "side": "left" }"#, "clips", #"clips[0] (box): unknown key "side""#),
            (#"{ "adjust": "vivid", "label": "x" }"#, "clips", #"clips[0] (adjustment): unknown key "label""#)
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

    @Test("media that was not probed stops")
    func refusesUnprobedMedia() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/unknown.mov" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].media (storyline clip): media "/abs/unknown.mov" has no probed kind"#)
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
            (#"{ "clips": [ { "title": "a", "shape": "box" } ] }"#, #"clips[0] (clip): takes only one of "title", "shape""#),
            (#"{ "storyline": [ { "title": "a", "style": "headline" } ] }"#, #"storyline[0] (storyline clip): unknown key "title". Allowed: media, solid"#),
            (##"{ "clips": [ { "solid": "#000000" } ] }"##, #"clips[0] (clip): unknown key "solid". Allowed: media, title, shape, adjust"#),
            (#"{ "clips": [ { "shape": "circle" } ] }"#, #"clips[0].shape (shape): unknown value "circle". Allowed: box, fill, dim, arrow"#)
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

    @Test("an arrow names its side")
    func requiresArrowSide() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "shape": "arrow", "area": [0, 0, 10, 10] } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"clips[0] (arrow): missing key "side""#)
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
            (#"{ "shape": "box", "keyframes": [ { "at": 1, "position": [0, 0] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "position". Allowed: at, ease, area, opacity"#),
            (#"{ "title": "a", "style": "headline", "keyframes": [ { "at": 1, "crop": [0, 0, 1, 1] } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "crop". Allowed: at, ease, position, scale, rotation, opacity"#),
            (#"{ "media": "/abs/bgm.m4a", "keyframes": [ { "at": 1, "opacity": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "opacity". Allowed: at, ease, volume"#),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1, "volume": 0 } ] }"#, #"clips[0].keyframes[0] (keyframe): unknown key "volume". Allowed: at, ease, position, scale, rotation, opacity, crop"#),
            (#"{ "media": "/abs/log.png", "at": [0, 1], "keyframes": [ { "at": 1 } ] }"#, "clips[0].keyframes[0] (keyframe): needs one of position, scale, rotation, opacity, crop"),
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

    @Test("an id is a string unique within its document, and a nested document has its own")
    func checksIdentifiers() throws {
        // Given
        let duplicate = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "id": "a", "title": "x", "style": "s" }, { "id": "a", "shape": "box" } ] }"#)
        let nested = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "id": "a", "media": { "kind": "sequence", "storyline": [ { "id": "a", "media": "/abs/run.mp4" } ] } }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: duplicate) }
        #expect(error?.description == #"clips[1]#a (box): id "a" is already used at clips[0]#a"#)
        try sut.check(document: nested)
    }

    @Test("metadata is an object whose contents are not checked")
    func leavesMetadataUnchecked() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "shape": "dim", "metadata": { "by": "redactor", "anything": [1, { "param": "x" }] } } ] }"#)
        let notObject = try Fixture.json(#"{ "kind": "sequence", "clips": [ { "shape": "dim", "metadata": "note" } ] }"#)

        // When, Then
        try sut.check(document: document)
        #expect(throws: ModelError.self) { try sut.check(document: notObject) }
    }

    @Test(
        "values of the wrong form stop",
        arguments: [
            #"{ "clips": [ { "title": "a", "style": "s", "at": 2 } ] }"#,
            #"{ "clips": [ { "shape": "box", "area": "Send" } ] }"#,
            #"{ "clips": [ { "title": "a", "style": "s", "position": { "area": "Send", "point": "left" } } ] }"#,
            #"{ "clips": [ { "shape": "box", "lane": 1.5 } ] }"#,
            ##"{ "clips": [ { "shape": "box", "color": "#12345" } ] }"##,
            #"{ "clips": [ { "shape": "box", "blend": "add" } ] }"#,
            #"{ "clips": [ { "title": "a", "style": "s", "placement": "middle" } ] }"#,
            #"{ "clips": [ { "media": "/abs/log.png", "at": [0, 1], "border": false } ] }"#,
            #"{ "clips": [ { "shape": "box", "keyframes": [ { "at": 0, "opacity": 1, "ease": "ease" } ] } ] }"#,
            #"{ "clips": [ { "shape": "box", "keyframes": [ { "at": 0, "opacity": 1, "ease": [1.2, 0, 0.5, 1] } ] } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "transition": { "seconds": 1 } } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "filter": ["vivid", 2] } ] }"#,
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
        "every form the specification gives a value is taken",
        arguments: [
            #"{ "clips": [ { "media": "/abs/run.mp4", "at": 2 } ] }"#,
            #"{ "clips": [ { "media": "/abs/log.png", "at": [0, 1], "border": "accent", "conform": "fill", "anchor": "top-left" } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "connected": [ { "title": "a", "style": "s", "parent": true, "position": { "area": "Send", "point": "left" }, "anchor": "right" } ] } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "crop": { "band": { "text": "a", "nth": 1 } }, "track": { "from": "a", "to": "b", "fromNth": 0, "toNth": 1 } } ] }"#,
            #"{ "storyline": [ { "media": { "imageSequence": "/abs/frames", "fps": 30 }, "in": 0, "out": 2 } ] }"#,
            #"{ "storyline": [ { "media": "/abs/run.mp4", "filter": ["vivid", "pack/warm", "/abs/f.json"], "transition": "cut" } ] }"#,
            #"{ "clips": [ { "shape": "box", "keyframes": [ { "at": 0, "opacity": 1, "ease": [0.25, 0.1, 0.25, 1] }, { "at": 1, "opacity": 0 } ] } ] }"#,
            #"{ "clips": [ { "shape": "arrow", "area": [0, 0, 10, 10], "side": "left", "labelAnimation": "none", "animation": { "entrance": "pop", "exit": "none" } } ] }"#
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
            (#"{ "clips": [ { "shape": "box", "animation": { "entrance": "pop" } } ] }"#, #"clips[0].animation (animation choice): missing key "exit""#),
            (#"{ "clips": [ { "shape": "box", "animation": { "exit": "fade" } } ] }"#, #"clips[0].animation (animation choice): missing key "entrance""#),
            (#"{ "storyline": [ { "media": "/abs/run.mp4", "transition": { "preset": "push-up" } } ] }"#, #"storyline[0].transition (transition choice): missing key "seconds""#),
            (#"{ "theme": { "defaults": { "transition": { "preset": "push-up" } } } }"#, #"theme.defaults.transition (transition choice): missing key "seconds""#)
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

    @Test("an unknown document kind stops")
    func refusesUnknownDocumentKind() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "movie" }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"kind (document): unknown value "movie". Allowed: image, layout, sequence"#)
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
              { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2, "transition": { "preset": "flash", "seconds": 0 } }
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
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "title": "Hi", "style": "label", "at": [0, 1], "position": [0, 0], "width": 0 } ] }
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
