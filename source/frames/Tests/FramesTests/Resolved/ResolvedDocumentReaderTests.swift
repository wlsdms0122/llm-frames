//
//  ResolvedDocumentReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("ResolvedDocumentReader Tests")
struct ResolvedDocumentReaderTests {
    // MARK: - Property
    private let sut = ResolvedDocumentReader()
    private let writer = ResolvedDocumentWriter()

    // A transition with spans, a video cover and a still matte, one that crossfades at constant gain, springs among their
    // eases, a filter with a LUT, and one that displaces by a map with its argument as the x of its offset.
    private static let presets = PresetTable(
        transitions: Fixture.presets.transitions.merging([
            "reveal": TransitionPreset(
                description: "",
                seconds: 1,
                over: .incoming,
                audio: .constantPower,
                incoming: Span(ease: .easeOut, keys: [SpanKey(t: 0, values: [.scale: 1.2, .opacity: 0]), SpanKey(t: 1, values: [:])]),
                outgoing: nil,
                cover: Cover(source: .media("/abs/leak.mov"), span: Span(ease: .spring(bounce: 0.6), keys: [])),
                matte: Matte(media: "/abs/matte.png", softness: 0.1, isInverted: true, ease: .cubicBezier(x1: 0.3, y1: 0, x2: 0.2, y2: 1))
            ),
            "dip": TransitionPreset(
                description: "",
                seconds: 1,
                over: .outgoing,
                audio: .constantGain,
                incoming: nil,
                outgoing: Span(ease: .spring(bounce: -0.4), revealFrom: .top, keys: [SpanKey(t: 0, values: [.y: 0]), SpanKey(t: 1, values: [.y: 1])]),
                cover: Cover(source: .color("#FFFFFF"), span: Span(ease: .linear, keys: [SpanKey(t: 0.5, values: [.opacity: 1])])),
                matte: nil
            )
        ]) { $1 },
        animations: Fixture.presets.animations,
        filters: Fixture.presets.filters.merging([
            "film": #"""
                { "description": "", "ops": [ { "kind": "lut", "file": "/abs/film.cube", "amount": 0.5 },
                                             { "kind": "bloom", "amount": 0.5, "radius": 4, "color": "#FFFFFF" },
                                             { "kind": "levels", "input": [0, 1], "output": [0.1, 0.9] } ] }
                """#,
            "fade": #"""
                { "description": "", "params": { "black": { "type": "number", "default": 0, "description": "the black" } },
                  "ops": [ { "kind": "levels", "input": [ { "param": "black" }, 1 ], "output": [0, 1] } ] }
                """#,
            "ripple": #"""
                { "description": "", "params": { "drift": { "type": "number", "default": 0, "description": "the drift" } },
                  "ops": [ { "kind": "displace", "file": "/abs/matte.png", "amount": 4, "offset": [ { "param": "drift" }, 0 ] } ] }
                """#
        ]) { $1 }
    )

    // Documents that between them write every kind of resolved entry and value.
    private static let documents = [
        // A cropped, filtered storyline clip at speed 2, a title that pops in, a still with a border outside its box and
        // music.
        #"""
        { "kind": "sequence", "format": { "size": [1080, 1920] },
          "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "filter": "mine/grade",
                           "keyframes": [ { "at": 2, "crop": [0, 0, 1080, 1920] }, { "at": 8, "crop": [45, 97, 990, 1760] } ] } ],
          "clips": [ { "kind": "title", "text": "Hi", "style": "title", "at": [0, 3], "animation": "frames/pop", "position": [75.4, 1709.8] },
                     { "kind": "media", "media": "/abs/page.png", "at": [0, 3], "width": 200, "border": { "align": "outside" }, "shadow": true, "radius": 12 },
                     { "kind": "audio", "media": "/abs/bgm.m4a", "at": 0, "loop": true,
                       "keyframes": [ { "at": 0, "volume": 0.3, "pan": -0.5, "ease": "ease-in" }, { "at": 2, "volume": 0.3 },
                                      { "at": 3, "volume": 0, "pan": 0.5 } ] } ] }
        """#,
        // A solid, an image sequence, a nested sequence, transitions with a cover and a matte, and a LUT.
        #"""
        { "kind": "sequence", "storyline": [
            { "kind": "solid", "color": "accent", "duration": 2 },
            { "kind": "media", "media": { "kind": "imageSequence", "directory": "/abs/frames", "fps": 12 }, "filter": "film", "transition": "reveal" },
            { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 2 } ] }, "transition": "dip" } ] }
        """#,
        // Shapes, tracked areas, an adjustment, a timed media clip, a title parented to a shape and sound with fades.
        shapes(trackedBy: Fixture.tracker),
        // Each shape kind and form: a rect by its area with a style, outset, a shadow object and a stroke inside its
        // outline, a rect by its width and height keyframed, an ellipse by its box at a position stroked outside, an
        // ellipse by its area with a named anchor, an open path with keyframed points and trim, a closed path, scaled
        // and turned, its ends a circle at scale 2 and a line arrow, and a curved path whose tangents keyframe apart from its
        // points.
        ##"""
        { "kind": "sequence",
          "theme": { "shapes": { "outline": { "stroke": { "width": 8, "paint": "#ED2929" }, "radius": 18 } } },
          "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 4 } ],
          "clips": [
            { "kind": "rect", "style": "outline", "area": [10, 20, 300, 200], "outset": 6, "shadow": { "radius": 4 },
              "stroke": { "align": "inside" }, "at": [0, 4] },
            { "kind": "rect", "fill": "accent", "height": 100, "placement": "top", "at": [0, 4],
              "keyframes": [ { "at": 0, "width": 200, "radius": 4, "ease": "ease-in" }, { "at": 2, "width": 400, "radius": 12 } ] },
            { "kind": "ellipse", "width": 120, "height": 60, "anchor": "top-left", "position": [100, 100], "outset": 2,
              "stroke": { "width": 3, "align": "outside", "join": "bevel", "cap": "square" }, "rotation": 30, "at": [0, 4] },
            { "kind": "ellipse", "area": [100, 100, 80, 40], "anchor": "bottom-right", "position": [400, 300], "fill": "#FFFFFF80",
              "shadow": true, "scale": 2, "at": [0, 4] },
            { "kind": "path", "stroke": { "width": 6, "start": { "preset": "frames/circle", "scale": 2 }, "end": "frames/line-arrow", "paint": "#00FF00" }, "at": [0, 4],
              "keyframes": [ { "at": 0, "points": [[0, 0], [100, 50], [200, 0]], "trim": [0, 0] },
                             { "at": 1, "points": [[0, 100], [100, 150], [200, 100]], "trim": [0.2, 1], "rotation": 45 } ] },
            { "kind": "path", "points": [[300, 300], [400, 300], [350, 380]], "closed": true, "fill": "accent", "stroke": false,
              "shadow": true, "at": [0, 4] },
            { "kind": "path", "stroke": { "width": 4 }, "anchor": "bottom", "position": [500, 500], "at": [0, 4],
              "points": [{ "vertex": [0, 0], "outTangent": [0, 40] }, [100, 0]],
              "keyframes": [ { "at": 0, "points": [{}, { "inTangent": [0, 40] }] }, { "at": 2, "points": [{}, { "inTangent": [0, 80] }] } ] } ] }
        """##,
        // Masks of each geometry form on a storyline clip, an adjustment, a shape and a title: an area, a box and a
        // path, inverted, feathered, in each mode, static and keyframed.
        #"""
        { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3,
            "mask": { "kind": "rect", "area": [96, 96, 208, 48], "radius": 6, "feather": 2, "invert": true },
            "connected": [
              { "kind": "adjustment", "adjust": "mine/grade", "parent": "screen", "mask": [
                  { "kind": "ellipse", "width": 60, "height": 30, "position": [100, 100], "mode": "subtract" },
                  { "kind": "path", "points": [[0, 0], [100, 0], [50, 80]], "mode": "intersect" } ] },
              { "kind": "rect", "fill": "#FF000080", "parent": "screen", "area": [0, 0, 500, 500], "mask": { "kind": "ellipse" }, "keyframes": [
                  { "at": 0, "ease": "ease-out", "mask": { "area": [100, 100, 200, 40], "feather": 1 } },
                  { "at": 2, "mask": { "area": [0, 0, 50, 50], "feather": 3 } } ] },
              { "kind": "title", "text": "Hi", "style": "title", "parent": "screen", "position": [300, 300], "mask": { "kind": "path" }, "keyframes": [
                  { "at": 0, "mask": { "points": [[0, 0], [10, 0], [5, 10]] } },
                  { "at": 1, "mask": { "points": [[0, 0], [20, 0], [10, 20]] } } ] } ] } ] }
        """#,
        // Track mattes: a storyline clip cut by a title's alpha, a still by a shape's inverted luma, and the shape by
        // the title in turn, so the title is the matte of two clips and the end of a chain.
        #"""
        { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 2,
            "trackMatte": { "clip": "word", "mode": "alpha" },
            "connected": [
              { "id": "word", "kind": "title", "text": "Hi", "style": "title", "at": [0, 1] },
              { "kind": "media", "media": "/abs/page.png", "at": [0, 1], "trackMatte": { "clip": "bar", "mode": "luma", "invert": true } } ] } ],
          "clips": [
            { "id": "bar", "kind": "rect", "fill": "#FFFFFF", "area": [0, 0, 10, 10], "at": [0, 1],
              "trackMatte": { "clip": "word", "mode": "alpha" } },
            { "id": "grade", "kind": "adjustment", "adjust": "mine/grade", "at": [0, 1] } ] }
        """#,
        // A filter whose preset argument and mix move, beside an op written in place.
        #"""
        { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3,
            "filter": [ "fade", { "kind": "exposure", "ev": 0.5 } ],
            "keyframes": [ { "at": 0, "filter": [ { "args": { "black": 0 } }, { "mix": 0 } ], "ease": "ease-in" },
                           { "at": 2, "filter": [ { "args": { "black": 0.2 } }, { "mix": 1 } ] } ] } ] }
        """#,
        // Time remapping: a storyline clip held, reversed and eased past the end of its media, and a connected media
        // clip remapped over its window, which writes no `in`, `out` or `loop`.
        #"""
        { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 6, "keyframes": [
            { "at": 0, "timeRemap": 1 }, { "at": 1, "timeRemap": 1, "ease": "ease-in" }, { "at": 3, "timeRemap": 0.5 } ],
            "connected": [ { "kind": "media", "media": "/abs/short.mp4", "at": [1, 3], "keyframes": [
              { "at": 1, "timeRemap": 3 }, { "at": 3, "timeRemap": 0 } ] } ] } ] }
        """#,
        // Audio filters: a storyline clip's held entries and a connected sound's band swept by its keyframes.
        #"""
        { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3,
            "audioFilter": [ { "kind": "gate", "threshold": -50 }, { "kind": "compressor", "threshold": -18, "ratio": 3, "mix": 0.5 } ] } ],
          "clips": [ { "kind": "audio", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "kind": "eq", "bands": [ { "kind": "peak", "gain": 6 } ] },
                       "keyframes": [ { "at": 0, "audioFilter": { "bands": [ { "frequency": 100, "q": 2 } ] } },
                                      { "at": 2, "audioFilter": { "bands": [ { "frequency": 8000, "q": 0.5 } ] } } ] } ] }
        """#,
        cornerPinDocument,
        storylineCornerPinDocument,
        // A sequence's own audio filter moved by its keyframes, and a compound clip's sound alone, which carries its nested
        // sequence's audio filter beside its own.
        #"""
        { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
          "clips": [ { "kind": "audio", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 2 } ],
                                  "audioFilter": { "kind": "limiter", "ceiling": -6, "lookahead": 0.01 } },
                       "at": 1, "audioFilter": { "kind": "gate", "threshold": -50 } } ],
          "audioFilter": [ { "kind": "gate", "threshold": -60 }, { "kind": "limiter", "ceiling": -1 } ],
          "keyframes": [ { "at": 0, "audioFilter": [ { "mix": 0 }, { "gain": 0 } ], "ease": "ease-in" },
                         { "at": 2, "audioFilter": [ { "mix": 1 }, { "gain": 2 } ] } ] }
        """#,
        // A displace written in place whose keyframes give its amount and move its offset, and a displace preset whose
        // argument moves the x of its offset.
        #"""
        { "kind": "sequence", "storyline": [
            { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": { "kind": "displace", "file": "/abs/matte.png" },
              "keyframes": [ { "at": 0, "filter": { "amount": 0, "offset": [0, 0] } },
                             { "at": 2, "filter": { "amount": 6, "offset": [12, -8] } } ] },
            { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": "ripple",
              "keyframes": [ { "at": 0, "filter": { "args": { "drift": 0 } } }, { "at": 2, "filter": { "args": { "drift": 30 } } } ] } ] }
        """#,
        // Convolutions, each impulse response pinned: a storyline clip's in an entry of its own `mix`, a compound clip's
        // whose gain moves beside its nested sequence's, and the sequence's before a limiter.
        #"""
        { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3,
            "audioFilter": { "kind": "convolve", "file": "/abs/ding.wav", "mix": 0.4 } } ],
          "clips": [ { "kind": "audio", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 2 } ],
                                  "audioFilter": { "kind": "convolve", "file": "/abs/bgm.m4a" } },
                       "at": 1, "audioFilter": { "kind": "convolve", "file": "/abs/ding.wav" },
                       "keyframes": [ { "at": 0, "audioFilter": { "gain": -12 } }, { "at": 1, "audioFilter": { "gain": 0 } } ] } ],
          "audioFilter": [ { "kind": "convolve", "file": "/abs/ding.wav", "gain": -6 }, { "kind": "limiter" } ] }
        """#,
        // A title of runs over two lines with a background, one run in the stroked subtitle style.
        #"""
        { "kind": "sequence", "format": { "size": [1920, 1080] },
          "theme": { "styles": { "card": { "size": 40, "background": { "color": "#000000", "padding": [4, 8], "radius": 6 } } } },
          "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
          "clips": [ { "kind": "title", "text": [ { "text": "Big", "style": "subtitle" }, { "text": " news\nToday" } ], "style": "card",
                       "at": [0, 2], "position": [200, 200] } ] }
        """#
    ]

    // A still, a title and a rect with corner pins, one keyframed and one with a point of another clip's area.
    private static let cornerPinDocument = #"""
        { "kind": "sequence", "format": { "size": [1920, 1080] },
          "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
          "clips": [ { "id": "card", "kind": "media", "media": "/abs/card.png", "at": [0, 3], "width": 300,
                       "keyframes": [ { "at": 0, "cornerPin": [[100, 100], [500, 120], [480, 400], [120, 380]] },
                                      { "at": 2, "cornerPin": [[110, 100], [510, 120], [490, 400], [130, 380]] } ] },
                     { "kind": "title", "text": "Hi", "style": "title", "at": [0, 3], "cornerPin": [[600, 100], [900, 100], [900, 200], [600, 200]] },
                     { "kind": "rect", "fill": "accent", "width": 40, "height": 20, "at": [0, 3],
                       "cornerPin": [ { "area": { "clip": "card" }, "point": "bottom-left" }, [500, 500], [500, 600], [400, 600] ] } ] }
        """#

    // A storyline entry with a corner pin, one without and a solid.
    private static let storylineCornerPinDocument = #"""
        { "kind": "sequence", "format": { "size": [1920, 1080] },
          "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 1,
                           "keyframes": [ { "at": 0, "cornerPin": [[100, 100], [500, 120], [480, 400], [120, 380]] },
                                          { "at": 1, "cornerPin": [[110, 100], [510, 120], [490, 400], [130, 380]] } ] },
                         { "kind": "media", "media": "/abs/run.mp4", "out": 1 },
                         { "kind": "solid", "color": "#000000", "duration": 1 } ] }
        """#

    // A tracked screen, a shape that follows the screen it is parented to, and a media clip of video under it that
    // follows its own media, each from the frame its instant shows.
    private static let trackedDocument = {
        let total = Quad(Fixture.total)
        let screen = Fixture.tracker.data(total, in: "/abs/screen.mp4", atMediaTime: 0, over: 0...3)
        let short = Fixture.tracker.data(Quad(Fixture.send), in: "/abs/short.mp4", atMediaTime: 0, over: 0...2)
        return #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3, "track": \#(screen), "connected": [
                { "kind": "rect", "stroke": { "width": 8 }, "area": [100, 100, 200, 40], "parent": "screen", "track": \#(screen) },
                { "kind": "media", "media": "/abs/short.mp4", "parent": "screen", "position": [0, 0], "at": [0, 2], "track": \#(short) } ] } ] }
            """#
    }()

    // A vertical title whose combined run "12" is set as a composition, "2" falling back to another face where the
    // shaper is told it is missing, animated by character over a tracking keyframed from 0 to 100.
    private static let compositionInTwoFaces = #"""
        { "kind": "sequence", "format": { "size": [1920, 1080] },
          "theme": { "styles": { "caption": { "size": 40 }, "date": { "size": 40, "textCombineUpright": "all" } } },
          "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
          "clips": [ { "kind": "title", "text": [ { "text": "漢" }, { "text": "12", "style": "date" }, { "text": "字" } ], "style": "caption",
                       "paragraph": { "writingMode": "vertical-rl" }, "at": [0, 2], "position": [0, 0],
                       "animation": { "preset": "frames/fade", "by": "character" },
                       "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] } ] }
        """#

    // The title `name` of the example of the resolved document, written whole with its hashes in full.
    private static let nameTitle = #"""
        { "size": [216.2, 55.9], "textBox": [0, 0, 216.2, 55.9], "width": null, "background": null,
          "writingMode": "horizontal-tb", "direction": "ltr", "align": "left", "lineHeight": [ { "at": 1.2, "value": 60, "ease": "linear" } ],
          "text": "Mina Baker", "words": [ [0, 4], [5, 10] ],
          "lines": [ { "width": 216.2, "baseline": 45.7, "ascent": 45.7, "descent": 10.2, "range": [0, 10],
                       "clusters": [ [0, 0, 1, 0, 1, 41.8, 0, ""], [0, 1, 1, 1, 2, 12.4, 0, ""],
                                     [0, 2, 1, 2, 3, 28.5, 0, ""], [0, 3, 1, 3, 4, 27.6, 0, ""],
                                     [0, 4, 1, 4, 5, 13.3, 0, ""], [1, 0, 1, 5, 6, 24.7, 0, ""],
                                     [1, 1, 1, 6, 7, 19.3, 0, ""], [1, 2, 1, 7, 8, 18, 0, ""],
                                     [1, 3, 1, 8, 9, 19.3, 0, ""], [1, 4, 1, 9, 10, 11.3, 0, ""] ],
                       "hanging": [] } ],
          "units": null,
          "runs": [
            { "source": 0, "file": "/System/Library/Fonts/HelveticaNeue.ttc",
              "sha256": "41aa0c9e5d17b2f3a8c4e6d1907b5f2e3c8a1d4b6e9f0a2c5d7e8b1f3a6c9d0e", "face": "HelveticaNeue-Bold", "size": 48,
              "color": [ { "at": 1.2, "value": "color(srgb 1 1 1 / 1)", "ease": "linear" } ], "stroke": null,
              "baselineShift": [ { "at": 1.2, "value": 0, "ease": "linear" } ], "sideways": false, "horizontalScale": 1, "staticTracking": 0,
              "tracking": null,
              "highlight": null, "underline": null,
              "glyphs": [ [48, 0, 45.7, 0, 0], [76, 41.8, 45.7, 0, 0], [81, 54.2, 45.7, 0, 0], [68, 82.7, 45.7, 0, 0], [3, 110.3, 45.7, 0, 0] ] },
            { "source": 1, "file": "/System/Library/Fonts/HelveticaNeue.ttc",
              "sha256": "41aa0c9e5d17b2f3a8c4e6d1907b5f2e3c8a1d4b6e9f0a2c5d7e8b1f3a6c9d0e", "face": "HelveticaNeue", "size": 36,
              "color": [ { "at": 1.2, "value": "color(srgb 0.788235294117647 0.8392156862745098 0.9176470588235294 / 1)", "ease": "linear" } ],
              "stroke": null,
              "baselineShift": [ { "at": 1.2, "value": 0, "ease": "linear" } ], "sideways": false, "horizontalScale": 1, "staticTracking": 0,
              "tracking": null,
              "highlight": { "color": [ { "at": 1.2, "value": "color(srgb 0.9490196078431372 0.7176470588235294 0.0196078431372549 / 1)", "ease": "linear" } ],
                             "padding": [ { "at": 1.2, "value": [2, 8], "ease": "linear" } ],
                             "radius": [ { "at": 1.2, "value": [4, 4, 4, 4], "ease": "linear" } ],
                             "rects": [ [123.6, 11.4, 92.6, 42] ] },
              "underline": null,
              "glyphs": [ [37, 123.6, 45.7, 0, 0], [68, 148.3, 45.7, 0, 0], [78, 167.6, 45.7, 0, 0], [72, 185.6, 45.7, 0, 0], [85, 204.9, 45.7, 0, 0] ] } ] }
        """#

    // MARK: - Initializer
    // MARK: - Test
    @Test("a resolved document reads back to the model it was written from", arguments: documents.indices)
    func readsWrittenDocument(index: Int) throws {
        // Given
        let document = try resolved(Self.documents[index])
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
    }

    @Test("a title by word reads back with the order it was resolved with, reading order written out where the choice leaves it out", arguments: UnitOrder.allCases)
    func readsUnitOrder(order: UnitOrder) throws {
        // Given
        let animation = order == .forward
            ? #"{ "preset": "frames/fade", "by": "word" }"#
            : #"{ "preset": "frames/fade", "by": "word", "order": "\#(order.rawValue)" }"#
        let document = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab cd ef", "style": "title", "at": [0, 2], "position": [0, 0], "animation": \#(animation) } ] }
            """#)
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
        #expect(read.clips[0].animation.units == UnitStagger(by: .word, stagger: 0.12, order: order))
        #expect(text.contains(#""by": "word","#) && text.contains(#""order": "\#(order.rawValue)""#))
    }

    @Test(
        "an animation's `order` that is not null where `by` is, missing, or not an order's name stops when read",
        arguments: [
            (
                #"{ "entrance": null, "loop": null, "exit": null, "by": null, "stagger": null, "order": "center" }"#,
                #"clips[0].animation.order (clip): expected null where `by` is null, found "center""#
            ),
            (
                #"{ "entrance": null, "loop": null, "exit": null, "by": "word", "stagger": 0.12 }"#,
                #"clips[0].animation (clip): missing key "order""#
            ),
            (
                #"{ "entrance": null, "loop": null, "exit": null, "by": "word", "stagger": 0.12, "order": "inward" }"#,
                #"clips[0].animation.order (clip): unknown value "inward". Allowed: forward, backward, center, edges, random"#
            )
        ]
    )
    func refusesUnreadableOrder(
        animation: String,
        message: String
    ) throws {
        // Given
        let text = try replacing("animation", ofClip: 0, with: animation, in: written(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab cd", "style": "title", "at": [0, 1], "position": [0, 0],
                           "animation": { "preset": "frames/fade", "by": "word" } } ] }
            """#))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a tracked media clip of video with a corner pin reads back with the track of its parent's media")
    func readsPinnedTrack() throws {
        // Given
        let pin = Quad(
            topLeft: Point(x: 100, y: 100),
            topRight: Point(x: 500, y: 120),
            bottomRight: Point(x: 480, y: 400),
            bottomLeft: Point(x: 120, y: 380)
        )
        let track = Fixture.tracker.data(pin, in: "/abs/screen.mp4", atMediaTime: 1)
        let document = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3, "connected": [
                { "kind": "media", "media": "/abs/short.mp4", "parent": "screen", "at": [0, 2], "width": 300,
                  "cornerPin": [[100, 100], [500, 120], [480, 400], [120, 380]], "track": \#(track) } ] } ] }
            """#)
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
        #expect(read.clips[0].ownTrackedMedia == nil)
        #expect(read.clips[0].parentTrack?.track.mediaTime == 1)
    }

    @Test("a run's stroke reads back with the run, and a run without one reads back without")
    func readsRunStroke() throws {
        // Given
        let text = try written(Self.documents[Self.documents.count - 1])

        // When
        let read = try sut.read(text)

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let black = TimedValue.track([Keyframe(at: 0, value: .color(Color(written: "#000000")))])
        #expect(title.runs.map(\.stroke) == [
            .object([
                TimedMember(key: "width", value: .track([Keyframe(at: 0, value: .number(3))])),
                TimedMember(key: "color", value: black)
            ]),
            .off,
            .off
        ])
    }

    @Test(
        "a resolved document from a later minor version or another major version is refused, naming both versions",
        arguments: ["0.2.0", "1.0.0"]
    )
    func refusesOtherVersion(version: String) throws {
        // Given
        let text = try replacingFirst(#""resolved": "0.1.0""#, with: #""resolved": "\#(version)""#, in: written(Self.documents[0]))

        // When
        let error = #expect(throws: ResolveError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"""
            resolved (sequence): the resolved document was written by frames "\#(version)", and frames 0.1.0 reads only one \#
            written by frames 0.0 up to 0.1
            """#)
    }

    @Test("a document without resolved is not a resolved document")
    func refusesMissingVersion() throws {
        // Given
        let text = #"{ "kind": "sequence", "format": {}, "storyline": [], "clips": [], "audio": [] }"#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"top level (sequence): missing key "resolved""#)
    }

    @Test(
        "a member that is missing, of another type, or never written there stops, naming its place",
        arguments: [
            (#""in": 2,"#, "", #"storyline[0] (storyline clip): missing key "in""#),
            (#""speed": 2,"#, #""speed": "2","#, #"storyline[0].speed (storyline clip): expected a number, found "2""#),
            (#""at": 0,"#, #""at": [0],"#, #"storyline[0].position[0].at (storyline clip): expected a number, found a list of 1"#),
            (#""size": [1080, 1920],"#, #""size": [1080],"#, #"format.size (format): expected a list of 2 numbers, found a list of 1"#),
            (
                #""duration": 3,"#,
                #""duration": 3, "fsp": 30,"#,
                #"format (format): unknown key "fsp". Allowed: size, fps, duration, background, conform, colorSpace, peak, compositing, motionBlur"#
            ),
            (
                #""loop": true,"#,
                #""loop": true, "scale": [],"#,
                #"audio[1] (audio): unknown key "scale". Allowed: place, media, nested, in, origin, out, speed, loop, start, end, audible, volume, pan, fadeIn, fadeOut, incoming, outgoing, audioFilter"#
            )
        ]
    )
    func refusesUnreadableMember(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let text = try replacingFirst(written, with: replacement, in: self.written(Self.documents[0]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("an `audio` curve that is not a crossfade curve stops on a sound's crossfade, and a storyline transition carries none")
    func refusesUnknownCrossfadeCurve() throws {
        // Given
        let text = try written(Self.documents[1])
        let curve = #""audio": "constant-gain""#
        let last = try #require(text.range(of: curve, options: .backwards))
        let crossfade = text.replacingCharacters(in: last, with: #""audio": "linear""#)
        let transition = replacingFirst(#""over": "#, with: #""audio": "constant-gain", "over": "#, in: text)

        // When
        let crossfadeError = #expect(throws: ModelError.self) { try sut.read(crossfade) }
        let transitionError = #expect(throws: ModelError.self) { try sut.read(transition) }

        // Then
        #expect(crossfadeError?.description == #"audio[0].incoming.audio (crossfade): unknown value "linear". Allowed: constant-power, constant-gain"#)
        #expect(transitionError?.description == #"storyline[1].transition (transition): unknown key "audio". Allowed: start, end, over, incoming, outgoing, cover, matte"#)
    }

    @Test("an adjustment's blend is written, read back as written, and given to the item it draws")
    func keepsAdjustmentBlend() throws {
        // Given
        let text = try written(#"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": 0, "out": 2 } ],
              "clips": [ { "kind": "adjustment", "adjust": "mine/grade", "at": [0, 2], "blend": "screen" } ] }
            """#)

        // When
        let sequence = try sut.read(text)
        let list = Evaluator().displayList(of: sequence, at: 1)

        // Then
        let entry = try JSONReader().read(text).objectValue?["clips"]?.arrayValue?.first?.objectValue
        #expect(entry?["blend"] == .string("screen"))
        let blends = sequence.clips.compactMap { clip -> String? in
            guard case let .picture(_, composite) = clip.content else { return nil }

            return composite.blend
        }
        #expect(blends == ["screen"])
        #expect(list.items.last?.blend == "screen")
    }

    @Test("scale and rotation are read for anything drawn, and not for an adjustment")
    func refusesKeyOfAnotherClipKind() throws {
        // Given
        let text = try replacingFirst(#""adjust":"#, with: #""scale": [], "adjust":"#, in: written(Self.documents[2]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description.hasPrefix(#"clips[4] (clip): unknown key "scale""#) == true)
    }

    @Test(
        "a clip with a corner pin whose position or rotation is not null stops, and so does a corner pin of other than four points",
        arguments: [
            ("position", 0, #"[ { "at": 0, "value": [0, 0], "ease": "linear" } ]"#, "clips[0].position (clip): a clip with a corner pin is placed by it, so its position is null"),
            ("rotation", 1, #"[ { "at": 0, "value": 0, "ease": "linear" } ]"#, "clips[1].rotation (clip): a clip with a corner pin is placed by it, so its rotation is null"),
            ("cornerPin", 1, #"[ { "at": 0, "value": [[0, 0], [10, 0], [10, 10]], "ease": "linear" } ]"#, "clips[1].cornerPin[0].value (")
        ]
    )
    func refusesCornerPinPlacement(
        key: String,
        index: Int,
        value: String,
        message: String
    ) throws {
        // Given
        let text = try replacing(key, ofClip: index, with: value, in: written(Self.cornerPinDocument))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description.hasPrefix(message) == true)
    }

    @Test(
        "a shape entry's member of the wrong form stops, naming its place",
        arguments: [
            (#""kind": "rect""#, #""kind": "box""#, #"clips[0].kind (clip): unknown value "box". Allowed: media, title, rect, ellipse, path, adjustment, null"#),
            (#""join": "round""#, #""join": "square""#, #"clips[0].stroke.join (stroke): unknown value "square". Allowed: miter, round, bevel"#),
            (#""inset": 2"#, #""inset": 9"#, "clips[4].stroke.start (stroke): a head's inset is from 0 to its length 4, found 9"),
            (#""inset": 2"#, #""inset": 2, "shape": "circle""#, #"clips[4].stroke.start (stroke): unknown key "shape". Allowed: points, length, inset, scale"#),
            (#""cap": "butt""#, #""cap": "butt", "head": 8"#, #"clips[0].stroke (stroke): unknown key "head". Allowed: paint, width, align, join, cap, start, end, dash, dashOffset"#)
        ]
    )
    func refusesShapeMember(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let text = try replacingFirst(written, with: replacement, in: self.written(Self.documents[3]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test(
        "a stroke's end written as a bare name, the form only a clip writes, stops, since a resolved end is null or its head's values and scale",
        arguments: [("start", "none"), ("end", "arrow")]
    )
    func refusesNamedEnd(
        key: String,
        name: String
    ) throws {
        // Given
        let root = try #require(try JSONReader().read(written(Self.documents[3])).objectValue)
        var clips = try #require(root["clips"]?.arrayValue)
        let clip = try #require(clips[0].objectValue)
        let stroke = try #require(clip["stroke"]?.objectValue)
        clips[0] = .object(clip.setting("stroke", to: .object(stroke.setting(key, to: .string(name)))))
        let text = JSONWriter().write(.object(root.setting("clips", to: .array(clips))))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"clips[0].stroke.\#(key) (stroke): expected an object, found "\#(name)""#)
    }

    @Test(
        "a parent that names no clip with a picture, or a parent chain that comes back to itself, stops",
        arguments: [
            (#""parent": "a""#, #""parent": "ghost""#, #"clips[1].parent (clip): no clip in the document has the id "ghost""#),
            (#""parent": "a""#, #""parent": "sound""#, #"clips[1].parent (clip): no clip in the document has the id "sound""#),
            (
                #""parent": "screen""#,
                #""parent": "b""#,
                #"clips[0].parent (clip): the parent chain comes back to itself: "a" > "b" > "a""#
            )
        ]
    )
    func refusesParent(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 2 } ],
              "clips": [ { "id": "a", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "screen" },
                         { "id": "b", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "a" },
                         { "id": "sound", "kind": "audio", "media": "/abs/bgm.m4a", "at": [0, 1] } ] }
            """#
        let text = try replacingFirst(written, with: replacement, in: self.written(document))

        // When
        let error = #expect(throws: ResolveError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a format duration that is not above 0 stops", arguments: ["0", "-1"])
    func refusesDurationNotAboveZero(duration: String) throws {
        // Given
        let text = try replacingFirst(#""duration": 3,"#, with: #""duration": \#(duration),"#, in: written(Self.documents[0]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "format.duration (format): a sequence's duration is above 0, found \(duration)")
    }

    @Test("a root that is not an object stops")
    func refusesNonObjectRoot() throws {
        // Given
        let text = "[]"

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "top level (resolved document): expected an object, found a list of 0")
    }

    private static let point = #"[ { "at": 0, "value": [0, 0], "ease": "linear" } ]"#
    private static let rect = #"[ { "at": 0, "value": [0, 0, 10, 10], "ease": "linear" } ]"#

    @Test(
        "a mask that is not a closed path through two vertices with a tangent of each kind for each, has a negative feather, an unknown mode, both a rect and a box, or a geometry without its kind stops",
        arguments: [
            (
                #"{ "kind": "path", "vertices": [\#(Self.point), \#(Self.point)], "inTangents": [\#(Self.point), \#(Self.point)], "outTangents": [\#(Self.point), \#(Self.point)], "closed": false }"#, "0", #""add""#,
                "clips[0].mask[0].geometry (mask): a path mask is a closed path through at least two vertices, with an in and an out tangent for each"
            ),
            (
                #"{ "kind": "path", "vertices": [\#(Self.point)], "inTangents": [\#(Self.point)], "outTangents": [\#(Self.point)], "closed": true }"#, "0", #""add""#,
                "clips[0].mask[0].geometry (mask): a path mask is a closed path through at least two vertices, with an in and an out tangent for each"
            ),
            (
                #"{ "kind": "path", "vertices": [\#(Self.point), \#(Self.point)], "inTangents": [\#(Self.point)], "outTangents": [\#(Self.point), \#(Self.point)], "closed": true }"#, "0", #""add""#,
                "clips[0].mask[0].geometry (mask): a path mask is a closed path through at least two vertices, with an in and an out tangent for each"
            ),
            (
                #"{ "kind": "rect", "rect": \#(Self.rect), "radius": [ { "at": 0, "value": [0, 0, 0, 0], "ease": "linear" } ] }"#, "-1", #""add""#,
                "clips[0].mask[0].feather[0].value (mask): a feather is 0 or more, found -1"
            ),
            (
                #"{ "kind": "ellipse", "rect": \#(Self.rect) }"#, "0", #""multiply""#,
                #"clips[0].mask[0].mode (mask): unknown value "multiply". Allowed: add, subtract, intersect"#
            ),
            (
                #"{ "kind": "ellipse", "rect": \#(Self.rect), "width": [ { "at": 0, "value": 10, "ease": "linear" } ] }"#, "0", #""add""#,
                #"clips[0].mask[0].geometry (mask): takes only one of "rect", "width""#
            ),
            (
                #"{ "ellipse": { "rect": \#(Self.rect) } }"#, "0", #""add""#,
                #"clips[0].mask[0].geometry (mask): missing key "kind""#
            ),
            (
                #"{ "kind": "circle", "rect": \#(Self.rect) }"#, "0", #""add""#,
                #"clips[0].mask[0].geometry.kind (mask): unknown value "circle". Allowed: rect, ellipse, path"#
            )
        ]
    )
    func refusesMask(
        geometry: String,
        feather: String,
        mode: String,
        message: String
    ) throws {
        // Given
        let mask = #"""
            [ { "geometry": \#(geometry), "feather": [ { "at": 0, "value": \#(feather), "ease": "linear" } ], "invert": false, "mode": \#(mode) } ]
            """#
        let text = try replacing("mask", ofClip: 0, with: mask, in: written(Self.documents[4]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a mask list with no mask stops, since a clip without masks has null")
    func refusesEmptyMaskList() throws {
        // Given
        let text = try replacing(
            "mask",
            ofClip: 0,
            with: "[]",
            in: written(Self.documents[4])
        )

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "clips[0].mask (clip): a mask list holds at least one mask, and a clip without one has null")
    }

    @Test(
        "a track matte that names no clip, a storyline clip or an adjustment, or a chain that comes back to itself, stops",
        arguments: [
            (
                1,
                #"{ "clip": "ghost", "mode": "alpha", "invert": false }"#,
                #"clips[1].trackMatte.clip (clip): no clip in the document has the id "ghost", and a track matte is a clip of the same document"#
            ),
            (
                1,
                #"{ "clip": "screen", "mode": "alpha", "invert": false }"#,
                #"clips[1].trackMatte.clip (clip): "screen" is a storyline clip, and a track matte is a connected or sequence media clip, title or shape"#
            ),
            (
                1,
                #"{ "clip": "grade", "mode": "luma", "invert": false }"#,
                #"clips[1].trackMatte.clip (clip): "grade" is an adjustment clip, and a track matte is a connected or sequence media clip, title or shape"#
            ),
            (
                0,
                #"{ "clip": "bar", "mode": "alpha", "invert": false }"#,
                #"clips[0].trackMatte.clip (clip): the track matte chain comes back to itself: "word" > "bar" > "word""#
            )
        ]
    )
    func refusesTrackMatte(
        clip: Int,
        matte: String,
        message: String
    ) throws {
        // Given
        let text = try replacing("trackMatte", ofClip: clip, with: matte, in: written(Self.documents[5]))

        // When
        let error = #expect(throws: ResolveError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a track matte with a mode other than alpha or luma, or without invert, stops")
    func refusesTrackMatteMode() throws {
        // Given
        let unknown = try replacing(
            "trackMatte",
            ofClip: 1,
            with: #"{ "clip": "bar", "mode": "red", "invert": false }"#,
            in: written(Self.documents[5])
        )
        let missing = try replacing(
            "trackMatte",
            ofClip: 1,
            with: #"{ "clip": "bar", "mode": "luma" }"#,
            in: written(Self.documents[5])
        )

        // When
        let unknownError = #expect(throws: ModelError.self) { try sut.read(unknown) }
        let missingError = #expect(throws: ModelError.self) { try sut.read(missing) }

        // Then
        #expect(unknownError?.description == #"clips[1].trackMatte.mode (track matte): unknown value "red". Allowed: alpha, luma"#)
        #expect(missingError?.description.hasPrefix("clips[1].trackMatte (track matte): missing") == true)
    }

    @Test("a track that turns and grows reads back as it was written, each frame's motion with its turn")
    func readsTurningTrack() throws {
        // Given
        let tracker = TrackerTable(frameTimes: Fixture.tracker.frameTimes, drift: Point(x: 3, y: -2), growth: 0.1, turn: 30)
        let document = try resolved(Self.shapes(trackedBy: tracker))
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
        let track = try #require(read.clips.first?.track?.track)
        let last = try #require(track.samples.last)
        #expect(abs(last.motion.rotation - 30 * (last.time - track.mediaTime)) < 1e-9)
        #expect(last.motion.rotation > 0)
    }

    @Test(
        "a track motion that is not a similarity and a target of three points stop, naming their place",
        arguments: [
            (
                "motion",
                "[1, 0, 0, 2, 0, 0]",
                "clips[0].track.frames[0].motion (track): a track's motion is a move, one scale above 0 and one rotation, written [a, b, -b, a, tx, ty], found [1, 0, 0, 2, 0, 0]"
            ),
            (
                "motion",
                "[0, 0, 0, 0, 5, 5]",
                "clips[0].track.frames[0].motion (track): a track's motion is a move, one scale above 0 and one rotation, written [a, b, -b, a, tx, ty], found [0, 0, 0, 0, 5, 5]"
            ),
            (
                "target",
                "[[0, 0], [10, 0], [10, 10]]",
                "clips[0].track.target (track): expected a list of 4 points, found a list of 3"
            )
        ]
    )
    func refusesTrackShape(
        key: String,
        value: String,
        message: String
    ) throws {
        // Given
        let text = try replacingInTrack(ofClip: 0, in: written(Self.documents[2])) { track in
            guard key == "motion" else { return track.setting(key, to: try Fixture.json(value)) }

            var frames = try #require(track["frames"]?.arrayValue)
            let frame = try #require(frames[0].objectValue)
            frames[0] = .object(frame.setting(key, to: try Fixture.json(value)))
            return track.setting("frames", to: .array(frames))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a track reads back with the media it follows, its parent's for a shape and its own for a storyline clip and a media clip of video")
    func readsTrackedMedia() throws {
        // Given
        let document = try resolved(Self.trackedDocument)
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
    }

    @Test(
        "a track that pins other media than the one its clip follows stops, naming the track's media",
        arguments: [
            (
                "clips",
                0,
                "/abs/short.mp4",
                "clips[0].track.media (track): the clip follows its parent's media, so its track pins the media its parent shows"
            ),
            (
                "clips",
                1,
                "/abs/screen.mp4",
                "clips[1].track.media (track): the clip follows its own media, so its track pins the media the clip shows"
            ),
            (
                "storyline",
                0,
                "/abs/short.mp4",
                "storyline[0].track.media (track): the clip follows its own media, so its track pins the media the clip shows"
            )
        ]
    )
    func refusesTrackedMedia(
        list: String,
        index: Int,
        file: String,
        message: String
    ) throws {
        // Given
        // The screen and the shape follow the screen, and the media clip the short, so each is given the other's.
        let root = try #require(try JSONReader().read(written(Self.trackedDocument)).objectValue)
        let pinned = (root["clips"]?.arrayValue ?? []).compactMap { $0.objectValue?["track"]?.objectValue?["media"] }
        let media = try #require(pinned.first { $0.objectValue?["file"]?.stringValue == file })
        var entries = try #require(root[list]?.arrayValue)
        let entry = try #require(entries[index].objectValue)
        let track = try #require(entry["track"]?.objectValue)
        entries[index] = .object(entry.setting("track", to: .object(track.setting("media", to: media))))
        let text = JSONWriter().write(.object(root.setting(list, to: .array(entries))))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test(
        "pinned media and a cover without their kind, of another kind, or with a key their kind does not hold, and a matte with media keys of its own, stop",
        arguments: [
            (1, "media", "kind", nil, #"storyline[1].media (storyline clip): missing key "kind""#),
            (
                1,
                "media",
                "kind",
                #""video""#,
                #"storyline[1].media.kind (storyline clip): unknown value "video". Allowed: file, imageSequence, page, sequence"#
            ),
            (1, "media", "imageSequence", "[]", #"storyline[1].media (storyline clip): unknown key "imageSequence". Allowed: kind, files, frames"#),
            (1, "cover", "kind", nil, #"storyline[1].transition.cover (cover): missing key "kind""#),
            (2, "cover", "kind", #""color""#, #"storyline[2].transition.cover.kind (cover): unknown value "color". Allowed: solid, media"#),
            (
                1,
                "cover",
                "file",
                #""/abs/leak.mov""#,
                #"storyline[1].transition.cover (cover): unknown key "file". Allowed: kind, media, colorSpace, duration, ease, revealFrom, keys"#
            ),
            (
                1,
                "matte",
                "file",
                #""/abs/matte.png""#,
                #"storyline[1].transition.matte (matte): unknown key "file". Allowed: media, colorSpace, duration, softness, invert, ease"#
            )
        ] as [(Int, String, String, String?, String)]
    )
    func refusesMediaWithoutKind(
        index: Int,
        key: String,
        member: String,
        replacement: String?,
        message: String
    ) throws {
        // Given
        let root = try #require(try JSONReader().read(written(Self.documents[1])).objectValue)
        var entries = try #require(root["storyline"]?.arrayValue)
        let entry = try #require(entries[index].objectValue)
        let transition = try #require(entry["transition"]?.objectValue)
        let object = try #require((key == "media" ? entry[key] : transition[key])?.objectValue)
        let edited = try replacement.map { object.setting(member, to: try JSONReader().read($0)) }
            ?? JSONObject(members: object.members.filter { $0.key != member })
        entries[index] = key == "media"
            ? .object(entry.setting(key, to: .object(edited)))
            : .object(entry.setting("transition", to: .object(transition.setting(key, to: .object(edited)))))
        let text = JSONWriter().write(.object(root.setting("storyline", to: .array(entries))))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a title read back from a file keeps its static tracking and draws each mark where the font places it")
    func drawsMarksReadFromFile() throws {
        // Given
        // The acute is placed 0.3 em left of and 0.2 em above its pen, and the title's runs are set 100 apart.
        let shaper = ShaperTable(placements: ["\u{301}": Point(x: -0.3, y: -0.2)])
        let document = try resolved(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "e\u0301x", "style": "title", "at": [0, 1], "position": [0, 0],
                           "character": { "tracking": 100 } } ] }
            """#,
            shaper: shaper
        )
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("frames-marks-\(UUID().uuidString).json")
        try writer.write(document).write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        // When
        let read = try sut.read(String(contentsOf: file, encoding: .utf8))

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let run = try #require(title.runs.first)
        let mark = try #require(run.glyphs.dropFirst().first)
        let drawn = GlyphsItem(text: title, factor: 1, at: SampleTime(0)).runs[0].glyphs[1]
        #expect(read == document)
        #expect(run.staticTracking == run.size / 10)
        #expect(mark.placementOffset == Point(x: -0.3 * run.size, y: -0.2 * run.size))
        #expect(Point(x: drawn.x, y: drawn.y) == Point(x: mark.x + mark.placementOffset.x, y: mark.y + mark.placementOffset.y))
    }

    @Test("a tracked title from resolve reads back, a ligature that ends its line taking no tracking after it")
    func readsTrackedLigature() throws {
        // Given
        let document = try resolved(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "xfi", "style": "title", "at": [0, 1], "position": [0, 0],
                           "character": { "tracking": 100, "features": { "liga": 1 } } } ] }
            """#
        )

        // When
        let read = try sut.read(writer.write(document))

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let line = try #require(title.lines.first)
        let tracking = title.runs[0].staticTracking
        #expect(read == document)
        #expect(tracking > 0)
        #expect(line.clusters.map(\.glyphs.count) == [1, 1, 0])
        #expect(abs(line.width - line.clusters[0].advance - tracking - line.clusters[1].advance) < 1e-9)
    }

    @Test("a title whose advances hold its tracking stops when read, naming the title's place")
    func refusesTrackingInAdvances() throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab", "style": "title", "at": [0, 1], "position": [0, 0], "character": { "tracking": 100 } } ] }
            """#
        )
        let folded = try replacingTitle(ofClip: 0, in: text) { title in
            var runs = try #require(title["runs"]?.arrayValue)
            let run = try #require(runs[0].objectValue)
            let tracking = try #require(run["staticTracking"]?.numberValue)
            runs[0] = .object(run.setting("staticTracking", to: .number(0)))
            var lines = try #require(title["lines"]?.arrayValue)
            let line = try #require(lines[0].objectValue)
            let clusters = try #require(line["clusters"]?.arrayValue).map { cluster in
                var numbers = try #require(cluster.arrayValue)
                numbers[5] = .number(try #require(numbers[5].numberValue) + tracking)

                return JSONValue.array(numbers)
            }
            lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            return title.setting("runs", to: .array(runs)).setting("lines", to: .array(lines))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(folded) }

        // Then
        #expect(error?.description == #"""
            clips[0].title (clip): line 0's pen positions do not follow its clusters' advances, its runs' static \#
            tracking and its width
            """#)
    }

    @Test("a right-to-left title from resolve reads back with its direction and its clusters' levels")
    func readsRightToLeftTitle() throws {
        // Given
        let document = try resolved(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "אב 12 cd", "style": "title", "at": [0, 1], "position": [0, 0],
                           "character": { "tracking": 100 } } ] }
            """#
        )

        // When
        let read = try sut.read(writer.write(document))

        // Then
        // The Hebrew letters lie at level 1 and the digits and Latin letters at level 2 by I2. The space after `ב` is R
        // by N1 and the one before `c` takes the paragraph's direction by N2, both at level 1, so the line is placed
        // c d, space, 1 2, space, ב א from left to right.
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let line = try #require(title.lines.first)
        #expect(read == document)
        #expect(title.direction == .rtl)
        #expect(line.clusters.map(\.level) == [1, 1, 1, 2, 2, 1, 2, 2])
        #expect(line.placedOrder == [6, 7, 5, 3, 4, 2, 1, 0])
    }

    @Test("pens are checked in the order they are placed in, with the tracking of whichever neighbour comes first")
    func readsPensInPlacedOrder() throws {
        // Given
        // Placed `ב א c`, both gaps take the static tracking of the run of `א`, which comes first in the text in each
        // pair, and neither takes that of the small run of `ב`.
        let document = try resolved(
            #"""
            { "kind": "sequence", "theme": { "styles": { "small": { "size": 20 } } },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": [ { "text": "א" }, { "text": "בc", "style": "small" } ], "style": "title",
                           "at": [0, 1], "position": [0, 0], "paragraph": { "direction": "ltr" },
                           "character": { "tracking": 100 } } ] }
            """#
        )
        let text = writer.write(document)
        let reordered = try replacingTitle(ofClip: 0, in: text) { title in
            var lines = try #require(title["lines"]?.arrayValue)
            let line = try #require(lines[0].objectValue)
            let clusters = try #require(line["clusters"]?.arrayValue).map { cluster in
                var numbers = try #require(cluster.arrayValue)
                numbers[6] = .number(0)

                return JSONValue.array(numbers)
            }
            lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            return title.setting("lines", to: .array(lines))
        }

        // When
        let read = try sut.read(text)
        let error = #expect(throws: ModelError.self) { try sut.read(reordered) }

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let line = try #require(title.lines.first)
        let wide = title.runs[line.clusters[0].glyphs.run].staticTracking
        #expect(read == document)
        #expect(line.clusters.map(\.level) == [1, 1, 0])
        #expect(abs(line.width - line.clusters.map(\.advance).reduce(0, +) - wide * 2) < 1e-9)
        #expect(error?.description.contains("line 0's pen positions do not follow its clusters' advances") == true)
    }

    @Test("a title's direction other than `ltr` or `rtl` stops when read, as `auto` is resolved before it is written")
    func refusesUnresolvedDirection() throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab", "style": "title", "at": [0, 1], "position": [0, 0] } ] }
            """#
        )
        let changed = try replacingTitle(ofClip: 0, in: text) { title in
            title.setting("direction", to: .string("auto"))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(changed) }

        // Then
        #expect(error?.description.contains("auto") == true)
        #expect(error?.description.contains("ltr") == true)
    }

    @Test("a title's writing mode is read as written, and one CSS does not name stops when read")
    func readsWritingMode() throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab", "style": "title", "at": [0, 1], "position": [0, 0],
                           "paragraph": { "writingMode": "vertical-lr" } } ] }
            """#
        )
        let changed = try replacingTitle(ofClip: 0, in: text) { title in
            title.setting("writingMode", to: .string("sideways-rl"))
        }

        // When
        let read = try sut.read(text)
        let error = #expect(throws: ModelError.self) { try sut.read(changed) }

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        #expect(title.writingMode == .verticalLeftToRight)
        #expect(error?.description.contains("sideways-rl") == true)
        #expect(error?.description.contains("vertical-rl") == true)
    }

    @Test("a run's orientation is read as written, and one that is not a boolean stops when read")
    func readsSideways() throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "縦A", "style": "title", "at": [0, 1], "position": [0, 0],
                           "paragraph": { "writingMode": "vertical-rl" } } ] }
            """#
        )
        let changed = try replacingTitle(ofClip: 0, in: text) { title in
            var runs = try #require(title["runs"]?.arrayValue)
            let run = try #require(runs[1].objectValue)
            runs[1] = .object(run.setting("sideways", to: .string("true")))

            return title.setting("runs", to: .array(runs))
        }

        // When
        let read = try sut.read(text)
        let error = #expect(throws: ModelError.self) { try sut.read(changed) }

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        #expect(title.runs.map(\.isSideways) == [false, true])
        #expect(error?.description.contains("sideways") == true)
    }

    @Test("a run's horizontal scale is read and written back as written, and one that is not a number stops when read")
    func readsHorizontalScale() throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "12", "style": "title", "at": [0, 1], "position": [0, 0] } ] }
            """#
        )
        let change = { (scale: JSONValue) in
            try self.replacingTitle(ofClip: 0, in: text) { title in
                var runs = try #require(title["runs"]?.arrayValue)
                let run = try #require(runs[0].objectValue)
                runs[0] = .object(run.setting("horizontalScale", to: scale))

                return title.setting("runs", to: .array(runs))
            }
        }
        let narrowed = try change(.number(0.5))
        let unreadable = try change(.string("0.5"))

        // When
        let read = try sut.read(text)
        let readNarrowed = try sut.read(narrowed)
        let rewritten = try sut.read(writer.write(readNarrowed))
        let error = #expect(throws: ModelError.self) { try sut.read(unreadable) }

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content,
            case let .picture(.title(narrowedTitle), _) = readNarrowed.clips.first?.content,
            case let .picture(.title(rewrittenTitle), _) = rewritten.clips.first?.content
        else {
            Issue.record("the first clip is not a title")
            return
        }
        #expect(title.runs.map(\.horizontalScale) == [1])
        #expect(narrowedTitle.runs.map(\.horizontalScale) == [0.5])
        #expect(rewrittenTitle.runs.map(\.horizontalScale) == [0.5])
        #expect(error?.description.contains("horizontalScale") == true)
    }

    @Test(
        "a composition set in two faces reads back as one group whose glyphs run on into the next glyph run, its characters sharing one box and its unit carrying and moving all its glyphs"
    )
    func readsCompositionInTwoFaces() throws {
        // Given
        // At size 40 every character is 40 down the line, and a tracking of 100 adds 4 between two of them.
        let document = try resolved(Self.compositionInTwoFaces, shaper: ShaperTable(missing: ["2"]))
        let text = writer.write(document)
        let time = SampleTime(1)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
        #expect(writer.write(read) == text)
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let face = title.runs[0].face
        #expect(title.runs.map(\.face) == [face, face, ShaperTable.fallback.name, face])
        #expect(title.lines[0].clusters.map(\.glyphs) == [
            GlyphRange(run: 0, first: 0, count: 1),
            GlyphRange(run: 1, first: 0, count: 2),
            GlyphRange(run: 2, first: 1, count: 0),
            GlyphRange(run: 3, first: 0, count: 1)
        ])
        #expect(title.glyphMoves(at: time) == [[Point(x: 0, y: 0)], [Point(x: 0, y: 4)], [Point(x: 0, y: 4)], [Point(x: 0, y: 8)]])
        #expect(title.characters(at: time).map(\.rect) == [
            Rectangle(x: 0, y: 0, width: 40, height: 40),
            Rectangle(x: 0, y: 44, width: 40, height: 40),
            Rectangle(x: 0, y: 44, width: 40, height: 40),
            Rectangle(x: 0, y: 88, width: 40, height: 40)
        ])

        let units = try #require(title.units)
        let whole = GlyphsItem(text: title, factor: 1, at: time)
        let sut = GlyphsItem(
            drawing: UnitDrawing(layer: .fills, index: 1, box: title.unitBox(of: 1, at: time)),
            carrying: units[1].glyphs,
            parts: [],
            extent: title.extent(of: 1, at: time),
            of: whole,
            factor: 1
        )
        #expect(units.map(\.glyphs) == [
            [GlyphRange(run: 0, first: 0, count: 1)],
            [GlyphRange(run: 1, first: 0, count: 1), GlyphRange(run: 2, first: 0, count: 1)],
            [GlyphRange(run: 3, first: 0, count: 1)]
        ])
        #expect(sut.runs.map(\.glyphs) == [whole.runs[1].glyphs, whole.runs[2].glyphs])
        #expect(title.unitBox(of: 1, at: time) == Rectangle(x: 0, y: 44, width: 40, height: 40))
    }

    @Test(
        "a cluster's glyph range that starts past its glyph run's glyphs or runs on past the title's last glyph run stops when read",
        arguments: [
            (1, [1, 1, 1]),
            (1, [1, 0, 4]),
            (3, [3, 0, 2])
        ]
    )
    func refusesGlyphRangePastRuns(
        cluster index: Int,
        glyphs: [Double]
    ) throws {
        // Given
        let text = writer.write(try resolved(Self.compositionInTwoFaces, shaper: ShaperTable(missing: ["2"])))
        let changed = try replacingTitle(ofClip: 0, in: text) { title in
            var lines = try #require(title["lines"]?.arrayValue)
            let line = try #require(lines[0].objectValue)
            var clusters = try #require(line["clusters"]?.arrayValue)
            let numbers = try #require(clusters[index].arrayValue)
            clusters[index] = .array(glyphs.map(JSONValue.number) + numbers.dropFirst(3))
            lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            return title.setting("lines", to: .array(lines))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(changed) }

        // Then
        #expect(error?.description.contains(
            "lines[0].clusters[\(index)] (clip): expected [run, first, count, start, end, advance, level, cursive]"
        ) == true)
    }

    @Test(
        "a title's cluster, line or word range past its text, a level UAX #9 cannot give, a script code ISO 15924 cannot give, or clusters that do not go up along a line, stop when read",
        arguments: [
            ("cluster", "expected [run, first, count, start, end, advance, level, cursive] within the text's 5 scalars"),
            ("level", "expected [run, first, count, start, end, advance, level, cursive] within the text's 5 scalars"),
            ("deep level", "expected [run, first, count, start, end, advance, level, cursive] within the text's 5 scalars"),
            ("script", "expected distinct ISO 15924 script codes separated by spaces"),
            ("line", "expected [start, end] within the text's 5 scalars"),
            ("word", "expected [start, end] within the text's 5 scalars"),
            ("order", "line 0's clusters do not go up along the text")
        ]
    )
    func refusesTextRange(
        change: String,
        message: String
    ) throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab cd", "style": "title", "at": [0, 1], "position": [0, 0] } ] }
            """#
        )
        let changed = try replacingTitle(ofClip: 0, in: text) { title in
            var lines = try #require(title["lines"]?.arrayValue)
            let line = try #require(lines[0].objectValue)
            var clusters = try #require(line["clusters"]?.arrayValue)
            var words = try #require(title["words"]?.arrayValue)
            switch change {
            case "cluster":
                var numbers = try #require(clusters[4].arrayValue)
                numbers[4] = .number(99)
                clusters[4] = .array(numbers)
                lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            case "level":
                var numbers = try #require(clusters[0].arrayValue)
                numbers[6] = .number(-1)
                clusters[0] = .array(numbers)
                lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            case "deep level":
                // UAX #9 gives no level above 126, max_depth 125 raised by one.
                var numbers = try #require(clusters[0].arrayValue)
                numbers[6] = .number(127)
                clusters[0] = .array(numbers)
                lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            case "script":
                var values = try #require(clusters[0].arrayValue)
                values[7] = .string("Arab arab")
                clusters[0] = .array(values)
                lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            case "line":
                lines[0] = .object(line.setting("range", to: .array([.number(0), .number(99)])))

            case "word":
                words[0] = .array([.number(0), .number(99)])

            default:
                var numbers = try #require(clusters[1].arrayValue)
                numbers[3] = .number(0)
                numbers[4] = .number(1)
                clusters[1] = .array(numbers)
                lines[0] = .object(line.setting("clusters", to: .array(clusters)))
            }

            return title.setting("lines", to: .array(lines)).setting("words", to: .array(words))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(changed) }

        // Then
        #expect(error?.description.contains(message) == true)
    }

    @Test(
        "a unit's part naming a run past the title's runs, a piece past its run's pieces, a negative piece or a run with neither highlight nor underline stops when read",
        arguments: ["run", "piece", "negative piece", "plain run"]
    )
    func refusesUnitPart(change: String) throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab cd", "style": "title", "at": [0, 1], "position": [0, 0],
                           "character": { "highlight": { "color": "#FF0000" } },
                           "animation": { "preset": "frames/fade", "by": "word" } } ] }
            """#
        )
        let changed = try replacingTitle(ofClip: 0, in: text) { title in
            var runs = try #require(title["runs"]?.arrayValue)
            var units = try #require(title["units"]?.arrayValue)
            let unit = try #require(units[0].objectValue)
            var parts = try #require(unit["parts"]?.arrayValue)
            var part = try #require(parts.first?.arrayValue)
            switch change {
            case "run":
                part[0] = .number(Double(runs.count))

            case "piece":
                part[1] = .number(1)

            case "negative piece":
                part[1] = .number(-1)

            default:
                let run = try #require(runs[0].objectValue)
                runs[0] = .object(run.setting("highlight", to: .null))
            }
            parts[0] = .array(part)
            units[0] = .object(unit.setting("parts", to: .array(parts)))

            return title.setting("runs", to: .array(runs)).setting("units", to: .array(units))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(changed) }

        // Then
        #expect(error?.description.contains(
            "units[0].parts[0] (clip): expected [run, piece, x0, x1] naming a highlight or underline piece of one of the title's runs"
        ) == true)
    }

    @Test("a glyph id an OpenType face cannot hold stops when read", arguments: [-1, 65536])
    func refusesGlyphID(id: Double) throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab", "style": "title", "at": [0, 1], "position": [0, 0] } ] }
            """#
        )
        let changed = try replacingTitle(ofClip: 0, in: text) { title in
            var runs = try #require(title["runs"]?.arrayValue)
            let run = try #require(runs[0].objectValue)
            var glyphs = try #require(run["glyphs"]?.arrayValue)
            var glyph = try #require(glyphs.first?.arrayValue)
            glyph[0] = .number(id)
            glyphs[0] = .array(glyph)
            runs[0] = .object(run.setting("glyphs", to: .array(glyphs)))

            return title.setting("runs", to: .array(runs))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(changed) }

        // Then
        #expect(error?.description.contains(
            "runs[0].glyphs[0] (clip): expected [glyph id, x, y, dx, dy] with a glyph id from 0 to 65535"
        ) == true)
    }

    @Test("a tracked title of Arabic and Latin from resolve reads back with its clusters' cursive scripts, and stops without them")
    func readsCursiveScripts() throws {
        // Given
        let document = try resolved(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "ab مرحبا", "style": "title", "at": [0, 1], "position": [0, 0],
                           "character": { "tracking": 100 } } ] }
            """#
        )
        let text = writer.write(document)
        let stripped = try replacingTitle(ofClip: 0, in: text) { title in
            var lines = try #require(title["lines"]?.arrayValue)
            let line = try #require(lines[0].objectValue)
            let clusters = try #require(line["clusters"]?.arrayValue).map { cluster in
                var values = try #require(cluster.arrayValue)
                values[7] = .string("")

                return JSONValue.array(values)
            }
            lines[0] = .object(line.setting("clusters", to: .array(clusters)))

            return title.setting("lines", to: .array(lines))
        }

        // When
        let read = try sut.read(text)
        let error = #expect(throws: ModelError.self) { try sut.read(stripped) }

        // Then
        // Tracking lies between `a` and `b`, `b` and the space, and the space and the Arabic word, and not between the
        // word's letters. Read without their scripts, the word's pens lie closer than the tracking between its letters
        // would put them.
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let line = try #require(title.lines.first)
        let tracking = title.runs[0].staticTracking
        let scripts: [[String]] = [[], [], []] + Array(repeating: ["Arab"], count: 5)
        #expect(read == document)
        #expect(line.clusters.map(\.cursiveScripts) == scripts)
        #expect(abs(line.width - line.clusters.map(\.advance).reduce(0, +) - 3 * tracking) < 1e-9)
        #expect(error?.description.contains("line 0's pen positions do not follow its clusters' advances") == true)
    }

    @Test("a vertical title from resolve reads back as it was resolved, its pens checked down its lines")
    func readsVerticalTitle() throws {
        // Given
        let document = try resolved(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "kind": "title", "text": "縦A\n字b", "style": "title", "at": [0, 1], "position": [0, 0],
                           "paragraph": { "writingMode": "vertical-rl" },
                           "character": { "tracking": 100, "highlight": { "color": "#FF0000", "padding": [4, 6] },
                                          "underline": true },
                           "animation": { "preset": "frames/fade", "by": "word" } } ] }
            """#
        )
        let text = writer.write(document)
        let moved = try replacingTitle(ofClip: 0, in: text) { title in
            var runs = try #require(title["runs"]?.arrayValue)
            let run = try #require(runs[1].objectValue)
            var glyphs = try #require(run["glyphs"]?.arrayValue)
            var glyph = try #require(glyphs.first?.arrayValue)
            glyph[2] = .number(try #require(glyph[2].numberValue) + 1)
            glyphs[0] = .array(glyph)
            runs[1] = .object(run.setting("glyphs", to: .array(glyphs)))

            return title.setting("runs", to: .array(runs))
        }

        // When
        let read = try sut.read(text)
        let error = #expect(throws: ModelError.self) { try sut.read(moved) }

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        // The first unit, `縦`, carries the part that starts its line's piece and ends where `A`'s begins, so its box
        // takes the highlight's second padding value at the top end and its first on both sides across the line, those
        // values as theme lengths.
        let unit = try #require(title.units?.first)
        let part = try #require(unit.parts.first)
        let across = unit.glyphBox.x - unit.box.x
        let down = part.span.lowerBound - unit.box.y
        #expect(read == document)
        #expect(title.writingMode == .verticalRightToLeft)
        #expect(title.lines.count == 2)
        #expect(title.lines[0].baseline > title.lines[1].baseline)
        #expect(title.runs[0].glyphs[0].x == title.lines[0].baseline)
        #expect(abs(down - across * 6 / 4) < 1e-9)
        #expect(abs(unit.box.width - unit.glyphBox.width - across * 2) < 1e-9)
        #expect(abs(unit.box.y + unit.box.height - part.span.upperBound) < 1e-9)
        #expect(error?.description.contains("line 0's pen positions do not follow its clusters' advances") == true)
    }

    @Test("the title of the example of the resolved document reads, and writes back as it was written")
    func readsExampleTitle() throws {
        // Given
        let text = try written(
            #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 6 } ],
              "clips": [ { "kind": "title", "text": "Mina Baker", "style": "title", "at": [1.2, 5], "position": [128, 900] } ] }
            """#
        )
        let name = try Fixture.json(Self.nameTitle)
        let document = try replacingTitle(ofClip: 0, in: text) { _ in try #require(name.objectValue) }

        // When
        let read = try sut.read(document)

        // Then
        guard case let .picture(.title(title), _) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        let written = try #require(writer.document(read).objectValue)
        let clip = try #require(written["clips"]?.arrayValue?.first?.objectValue)
        #expect(title.text == "Mina Baker")
        #expect(clip["title"] == name)
    }

    // MARK: - Private
    // Shapes, two of them tracked from the frame their instant shows by what `tracker` follows, an adjustment, a timed
    // media clip, a title parented to a shape and sound with fades.
    private static func shapes(trackedBy tracker: TrackerTable) -> String {
        let total = Quad(Fixture.total)
        let box = Quad(Rectangle(x: 86, y: 86, width: 228, height: 68))
        let totalTrack = tracker.data(total, in: "/abs/screen.mp4", atMediaTime: 1, over: 1...3)
        let boxTrack = tracker.data(box, in: "/abs/screen.mp4", atMediaTime: 1, over: 1...3)
        return #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 1, "out": 3, "fadeIn": 0.5, "connected": [
                { "kind": "rect", "stroke": { "width": 8 }, "area": [100, 100, 200, 40], "parent": "screen", "track": \#(totalTrack) },
                { "kind": "rect", "fill": "#FFD43B80", "area": [86, 86, 228, 68], "parent": "screen", "track": \#(boxTrack) },
                { "kind": "path", "points": [[500, 500], [600, 550]], "stroke": { "width": 10, "end": "frames/arrow" }, "at": [1, 2], "lane": -1 },
                { "kind": "rect", "area": [0, 0, 100, 100], "fill": "#0000008C", "at": [1, 2], "id": "dim" },
                { "kind": "adjustment", "adjust": "mine/grade", "mask": { "kind": "rect", "area": [0, 0, 10, 10] }, "at": [1, 2] },
                { "kind": "media", "media": "/abs/short.mp4", "in": 1, "out": 3, "speed": 2, "at": 1, "width": 300, "conform": "fill",
                  "keyframes": [ { "at": 1, "opacity": 0, "ease": { "kind": "spring", "bounce": 0.3 } }, { "at": 1.5, "opacity": 1 } ] },
                { "kind": "title", "text": "Hi", "style": "title", "at": [1, 2], "parent": "dim", "position": [50, 50] },
                { "kind": "audio", "media": "/abs/ding.wav", "at": 1.5, "fadeIn": 0.25, "fadeOut": 0.5 } ] } ] }
            """#
    }

    private func resolved(
        _ document: String,
        shaper: ShaperTable = Fixture.shaper
    ) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Self.presets,
            shaper: shaper,
            library: Fixture.library
        )

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func written(_ document: String) throws -> String {
        writer.write(try resolved(document))
    }

    private func replacing(
        _ key: String,
        ofClip index: Int,
        with value: String,
        in text: String
    ) throws -> String {
        let root = try #require(try JSONReader().read(text).objectValue)
        var clips = try #require(root["clips"]?.arrayValue)
        let clip = try #require(clips[index].objectValue)
        clips[index] = .object(clip.setting(key, to: try Fixture.json(value)))

        return JSONWriter().write(.object(root.setting("clips", to: .array(clips))))
    }

    private func replacingTitle(
        ofClip index: Int,
        in text: String,
        _ change: (JSONObject) throws -> JSONObject
    ) throws -> String {
        let root = try #require(try JSONReader().read(text).objectValue)
        var clips = try #require(root["clips"]?.arrayValue)
        let clip = try #require(clips[index].objectValue)
        let title = try #require(clip["title"]?.objectValue)
        clips[index] = .object(clip.setting("title", to: .object(try change(title))))

        return JSONWriter().write(.object(root.setting("clips", to: .array(clips))))
    }

    private func replacingInTrack(
        ofClip index: Int,
        in text: String,
        _ change: (JSONObject) throws -> JSONObject
    ) throws -> String {
        let root = try #require(try JSONReader().read(text).objectValue)
        var clips = try #require(root["clips"]?.arrayValue)
        let clip = try #require(clips[index].objectValue)
        let track = try #require(clip["track"]?.objectValue)
        clips[index] = .object(clip.setting("track", to: .object(try change(track))))

        return JSONWriter().write(.object(root.setting("clips", to: .array(clips))))
    }

    private func replacingFirst(
        _ target: String,
        with replacement: String,
        in text: String
    ) -> String {
        guard let range = text.range(of: target) else {
            Issue.record("\(target) is not in the text")
            return text
        }

        return text.replacingCharacters(in: range, with: replacement)
    }
}
