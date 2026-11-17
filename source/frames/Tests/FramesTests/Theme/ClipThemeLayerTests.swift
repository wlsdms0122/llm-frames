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
            (#"{ "media": "/abs/run.mp4", "transition": "frames/flash", "filter": "frames/vivid" }"#, ClipKind.media(.video), #"{ "defaults": { "transition": "frames/flash", "filter": "frames/vivid" } }"#),
            (#"{ "title": "a", "style": "subtitle", "animation": "frames/pop" }"#, ClipKind.title, #"{ "defaults": { "animation": { "title": { "subtitle": "frames/pop" } } } }"#),
            (#"{ "shape": "arrow", "animation": "frames/draw", "labelAnimation": "none" }"#, ClipKind.shape("arrow"), #"{ "defaults": { "animation": { "shape": "frames/draw", "title": { "label": "none" } } } }"#),
            (#"{ "adjust": "frames/vivid", "animation": "frames/fade" }"#, ClipKind.adjust, #"{ "defaults": { "animation": { "adjust": "frames/fade" } } }"#),
            (#"{ "media": "/abs/log.png", "animation": "frames/pop" }"#, ClipKind.media(.image), #"{ "defaults": { "animation": { "media": "frames/pop" } } }"#),
            (#"{ "media": { "kind": "sequence" } }"#, ClipKind.media(.sequence), #"{ "defaults": { "filter": "none" } }"#),
            (#"{ "media": { "template": "pack/card" } }"#, ClipKind.media(.image), #"{ "defaults": { "filter": "none" } }"#),
            (#"{ "media": { "template": "pack/card" }, "filter": "frames/vivid" }"#, ClipKind.media(.image), #"{ "defaults": { "filter": "frames/vivid" } }"#)
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
