//
//  ClipThemeLayerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("ClipThemeLayer Tests")
struct ClipThemeLayerTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "the keys on a clip stand in for the theme values they name",
        arguments: [
            (#"{ "media": "/abs/run.mp4", "transition": "flash", "filter": "vivid" }"#, ClipKind.media(.video), #"{ "defaults": { "transition": "flash", "filter": "vivid" } }"#),
            (#"{ "title": "a", "style": "subtitle", "animation": "pop" }"#, ClipKind.title, #"{ "defaults": { "animation": { "title": { "subtitle": "pop" } } } }"#),
            (#"{ "shape": "arrow", "animation": "draw", "labelAnimation": "none" }"#, ClipKind.shape("arrow"), #"{ "defaults": { "animation": { "shape": "draw", "title": { "label": "none" } } } }"#),
            (#"{ "adjust": "vivid", "animation": "fade" }"#, ClipKind.adjust, #"{ "defaults": { "animation": { "adjust": "fade" } } }"#),
            (#"{ "media": "/abs/log.png", "animation": "pop" }"#, ClipKind.media(.image), #"{ "defaults": { "animation": { "media": "pop" } } }"#),
            (#"{ "media": { "kind": "sequence" } }"#, ClipKind.media(.sequence), #"{ "defaults": { "filter": "none" } }"#),
            (#"{ "media": { "template": "pack/card" } }"#, ClipKind.media(.image), #"{ "defaults": { "filter": "none" } }"#),
            (#"{ "media": { "template": "pack/card" }, "filter": "vivid" }"#, ClipKind.media(.image), #"{ "defaults": { "filter": "vivid" } }"#)
        ]
    )
    func layersClipKeys(
        clip: String,
        kind: ClipKind,
        expected: String
    ) throws {
        // Given
        let object = try Fixture.object(clip)

        // When
        let layer = ClipThemeLayer.layer(forClip: object, kind: kind)

        // Then
        #expect(layer == (try Fixture.json(expected)))
    }

    @Test("a shape op's colour replaces its shape's theme colour")
    func layersOperationColour() throws {
        // Given
        let operation = try Fixture.object(##"{ "shape": "fill", "area": "x", "color": "#000000" }"##)

        // When
        let layer = ClipThemeLayer.layer(forOperation: operation)

        // Then
        #expect(layer == (try Fixture.json(##"{ "shapes": { "fill": { "color": "#000000" } } }"##)))
    }
}
