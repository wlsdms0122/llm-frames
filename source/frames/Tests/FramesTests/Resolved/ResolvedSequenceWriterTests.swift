//
//  ResolvedSequenceWriterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ResolvedSequenceWriter Tests")
struct ResolvedSequenceWriterTests {
    // MARK: - Property
    private let sut = ResolvedDocumentWriter()
    private let hashes = FileHashTable(["/abs/run.mp4": "9f2c41d07b3e"])

    // A transition with spans, a cover and a matte, and a filter with a LUT, so every file a preset opens is pinned.
    private let presets = PresetTable(
        transitions: [
            "reveal": TransitionPreset(
                description: "",
                seconds: 1,
                over: .incoming,
                audio: .constantPower,
                incoming: Span(ease: .easeOut, keys: [SpanKey(t: 0, values: [.scale: 1.2, .opacity: 0]), SpanKey(t: 1, values: [:])]),
                outgoing: nil,
                cover: Cover(source: .media("/abs/leak.mov"), span: Span(ease: .linear, keys: [])),
                matte: Matte(media: "/abs/matte.png", softness: 0.1, isInverted: true, ease: .easeIn)
            )
        ],
        animations: Fixture.presets.animations,
        filters: ["film": #"{"description": "", "ops": [{"op": "lut", "file": "/abs/film.cube", "amount": 0.5}]}"#]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("the root is its kind, the version of this frames, then the sequence's members")
    func writesRoot() throws {
        // Given
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2 } ] }"#

        // When
        let resolved = try write(document)

        // Then
        #expect(resolved.keys == ["kind", "resolved", "format", "storyline", "clips", "audio"])
        #expect(resolved["kind"] == .string("sequence"))
        #expect(resolved["resolved"] == .string(FramesVersion.current))
        #expect(resolved["format"]?.objectValue?.keys == ["size", "fps", "duration", "background", "conform"])
        #expect(resolved["format"]?.objectValue?["duration"] == .number(3))
        #expect(resolved["format"]?.objectValue?["background"]?.stringValue?.count == 9)
    }

    @Test("a storyline entry keeps media time for in, out and speed, and sequence time for start and end")
    func writesStorylineTimes() throws {
        // Given
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2 } ] }"#

        // When
        let entry = try #require(try write(document)["storyline"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(entry["place"] == .string("storyline[0]"))
        #expect(entry["media"]?.objectValue?.keys == ["file", "sha256"])
        #expect(entry["media"]?.objectValue?["sha256"] == .string("9f2c41d07b3e"))
        #expect(entry["in"] == .number(2))
        #expect(entry["out"] == .number(8))
        #expect(entry["speed"] == .number(2))
        #expect(entry["start"] == .number(0))
        #expect(entry["end"] == .number(3))
        #expect(entry["transition"] == .null)
        #expect(entry["filter"] == .null)
    }

    @Test("a storyline crop is written conformed to the frame, and no crop is the whole picture conformed")
    func writesConformedCrop() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1000, 1380] },
              "storyline": [ { "media": "/abs/screen.mp4", "in": 0, "out": 1, "crop": [0, 0, 1206, 1206] },
                             { "media": "/abs/card.png", "duration": 1 } ] }
            """#
        let frame = Rectangle(x: 0, y: 0, width: 1000, height: 1380)
        let conformer = CropConformer()
        let cropped = conformer.conformed(Rectangle(x: 0, y: 0, width: 1206, height: 1206), to: frame, by: .fit)
        let whole = conformer.conformed(Rectangle(x: 0, y: 0, width: 1080, height: 1350), to: frame, by: .fit)

        // When
        let storyline = try #require(try write(document)["storyline"]?.arrayValue)

        // Then
        #expect(storyline[0].objectValue?["crop"] == keyframes(at: 0, cropped))
        #expect(storyline[1].objectValue?["crop"] == keyframes(at: 1, whole))
    }

    @Test("an image sequence is pinned frame by frame, in order, with its frame times")
    func pinsImageSequence() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": { "imageSequence": "/abs/frames", "fps": 12 } } ] }
            """#

        // When
        let media = try #require(try write(document)["storyline"]?.arrayValue?.first?.objectValue?["media"]?.objectValue)

        // Then
        let frames = try #require(media["imageSequence"]?.arrayValue)
        #expect(media.keys == ["imageSequence", "frames"])
        #expect(frames.compactMap { $0.objectValue?["file"]?.stringValue } == Fixture.imageSequenceFiles)
        #expect(frames.compactMap { $0.objectValue?["sha256"]?.stringValue } == Fixture.imageSequenceFiles.map { "sha256-of-" + $0 })
        #expect(media["frames"]?.arrayValue?.count == 12)
        #expect(media["frames"]?.arrayValue?[1] == .number(1.0 / 12))
    }

    @Test("a title carries its runs with the font pinned, and glyphs as [id, x, y] in its box")
    func writesShapedTitle() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "title": "Hi", "style": "title", "placement": "top", "at": [0, 1] } ] }
            """#

        // When
        let title = try #require(try write(document)["clips"]?.arrayValue?.first?.objectValue?["title"]?.objectValue)

        // Then
        let run = try #require(title["runs"]?.arrayValue?.first?.objectValue)
        #expect(title.keys == ["size", "textBox", "width", "background", "align", "lineHeight", "lines", "units", "runs"])
        #expect(run.keys == [
            "source", "file", "sha256", "face", "size", "color", "stroke", "baselineShift", "tracking", "highlight", "underline",
            "glyphs"
        ])
        #expect(run["sha256"] == .string("sha256-of-" + (run["file"]?.stringValue ?? "")))
        #expect(run["glyphs"]?.arrayValue?.compactMap { $0.arrayValue?.first } == [.number(72), .number(105)])
        #expect(run["glyphs"]?.arrayValue?.allSatisfy { $0.arrayValue?.count == 3 } == true)
    }

    @Test("a clip keeps its place, id, visible window, lane, storyline and parent, and its properties in sequence time")
    func writesClip() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "run", "media": "/abs/run.mp4", "in": 2, "out": 8, "connected": [
                { "id": "mark", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 100, 100], "at": [3, 5], "lane": -1, "parent": "run",
                  "keyframes": [ { "at": 3, "opacity": 0, "ease": [0.3, 0, 0.2, 1] }, { "at": 4, "opacity": 1 } ] } ] } ] }
            """#

        // When
        let clip = try #require(try write(document)["clips"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(clip["place"] == .string("storyline[0]#run.connected[0]#mark"))
        #expect(clip["id"] == .string("mark"))
        #expect(clip["shape"] == .string("rect"))
        #expect(clip["start"] == .number(1))
        #expect(clip["end"] == .number(3))
        #expect(clip["lane"] == .number(-1))
        #expect(clip["storyline"] == .number(0))
        #expect(clip["parent"] == .string("run"))
        #expect(clip["area"] == keyframes(at: 1, Rectangle(x: 0, y: 0, width: 100, height: 100)))
        #expect(clip["opacity"] == .array([
            .object(JSONObject(members: [
                JSONMember(key: "at", value: .number(1)),
                JSONMember(key: "value", value: .number(0)),
                JSONMember(key: "ease", value: .array([.number(0.3), .number(0), .number(0.2), .number(1)]))
            ])),
            .object(JSONObject(members: [
                JSONMember(key: "at", value: .number(2)),
                JSONMember(key: "value", value: .number(1)),
                JSONMember(key: "ease", value: .string("linear"))
            ]))
        ]))
        #expect(clip["scale"]?.arrayValue?.first?.objectValue?["value"] == .array([.number(1), .number(1)]))
        #expect(clip["blend"] == .string("normal"))
    }

    @Test("a scale keyframed as numbers and pairs is written as pairs")
    func writesScalePairs() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "connected": [
                { "shape": "rect", "fill": "accent", "area": [0, 0, 100, 100], "at": [0, 4],
                  "keyframes": [ { "at": 0, "scale": [2, 1] }, { "at": 1, "scale": 0.5 }, { "at": 2, "scale": [-1, 3] } ] } ] } ] }
            """#

        // When
        let clip = try #require(try write(document)["clips"]?.arrayValue?.first?.objectValue)

        // Then
        let values = clip["scale"]?.arrayValue?.map { $0.objectValue?["value"] }
        #expect(values == [
            .array([.number(2), .number(1)]),
            .array([.number(0.5), .number(0.5)]),
            .array([.number(-1), .number(3)])
        ])
    }

    @Test("a clip's parent is written as the id of the clip it names, any clip of the document, or null without one")
    func writesParent() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "run", "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "id": "bar", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 100, 20], "at": [0, 1] },
                         { "title": "a", "style": "title", "at": [0, 1], "parent": "bar", "position": [10, 10] },
                         { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "run" } ] }
            """#

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue)

        // Then
        #expect(clips.map { $0.objectValue?["parent"] } == [.null, .string("bar"), .string("run")])
    }

    @Test("a media clip carries its box, its crop conformed to it, its corners, border and shadow, with theme lengths scaled")
    func writesMediaAppearance() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "media": "/abs/card.png", "at": [0, 3], "width": 300, "height": 300, "conform": "fill", "position": [540, 960],
                           "radius": 12, "border": true, "shadow": true } ] }
            """#

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue)

        // Then
        let clip = try #require(clips.first?.objectValue)
        #expect(clip["size"] == .array([.number(300), .number(300)]))
        #expect(clip["position"] == .array([.object(JSONObject(members: [
            JSONMember(key: "at", value: .number(0)),
            JSONMember(key: "value", value: .array([.number(540), .number(960)])),
            JSONMember(key: "ease", value: .string("linear"))
        ]))]))
        #expect(clip["anchor"] == .array([.number(150), .number(150)]))
        #expect(clip["crop"] == keyframes(at: 0, Rectangle(x: 0, y: 135, width: 1080, height: 1080)))
        #expect(clip["conform"] == .string("fill"))
        #expect(clip["radius"] == held(.number(6.75)))
        #expect(clip["border"] == .object(JSONObject(members: [
            JSONMember(key: "width", value: held(.number(2.25))),
            JSONMember(key: "color", value: held(.string("#FFFFFFFF")))
        ])))
        #expect(clip["shadow"] == .object(JSONObject(members: [
            JSONMember(key: "radius", value: held(.number(18))),
            JSONMember(key: "offset", value: held(.array([.number(0), .number(6.75)]))),
            JSONMember(key: "color", value: held(.string("#00000080")))
        ])))
    }

    @Test("a border of true takes the theme border colour, never a theme colour named border, and a written colour replaces it")
    func writesBorderColor() throws {
        // Given
        let document = ##"""
            { "kind": "sequence",
              "theme": { "colors": { "ink": "#101418", "border": "#00FF00" }, "border": { "color": "ink" } },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "media": "/abs/card.png", "at": [0, 3], "border": true },
                         { "media": "/abs/card.png", "at": [0, 3], "border": "#FF0000" } ] }
            """##

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue)

        // Then
        let colors = clips.map { $0.objectValue?["border"]?.objectValue?["color"] }
        #expect(colors == [held(.string("#101418FF")), held(.string("#FF0000FF"))])
    }

    @Test("a solid storyline clip carries its colour as #RRGGBBAA, a theme colour by its value")
    func writesSolidColor() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "shadow", "duration": 1 } ] }
            """#

        // When
        let storyline = try #require(try write(document)["storyline"]?.arrayValue)

        // Then
        #expect(storyline.first?.objectValue?["solid"] == .string("#00000080"))
        #expect(storyline.first?.objectValue?["media"] == .null)
    }

    @Test("a transition carries its spans inline and its cover and matte media pinned with their frames and length, and a LUT is pinned")
    func writesTransitionAndLUT() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": "film" },
                                                 { "media": "/abs/run.mp4", "in": 0, "out": 3, "transition": "reveal" } ] }
            """#

        // When
        let storyline = try #require(try write(document, presets: presets)["storyline"]?.arrayValue)

        // Then
        let transition = try #require(storyline[1].objectValue?["transition"]?.objectValue)
        let incoming = try #require(transition["incoming"]?.objectValue)
        #expect(transition.keys == ["start", "end", "over", "incoming", "outgoing", "cover", "matte"])
        #expect(transition["start"] == .number(2.5))
        #expect(transition["end"] == .number(3.5))
        #expect(incoming["ease"] == .string("ease-out"))
        #expect(incoming["keys"]?.arrayValue?.first?.objectValue?.keys == ["t", "opacity", "scale"])
        #expect(transition["cover"]?.objectValue?.keys == ["file", "sha256", "frames", "duration", "ease", "revealFrom", "keys"])
        #expect(transition["cover"]?.objectValue?["sha256"] == .string("sha256-of-/abs/leak.mov"))
        #expect(transition["cover"]?.objectValue?["frames"] == .array([0, 0.5, 1, 1.5].map(JSONValue.number)))
        #expect(transition["cover"]?.objectValue?["duration"] == .number(2))
        #expect(transition["matte"]?.objectValue?.keys == ["file", "sha256", "duration", "softness", "invert", "ease"])
        #expect(transition["matte"]?.objectValue?["duration"] == .number(0))
        let entry = storyline[0].objectValue?["filter"]?.arrayValue?.first?.objectValue
        #expect(entry?.keys == ["ops", "mix"])
        #expect(entry?["ops"]?.arrayValue?.first?.objectValue?.keys == ["op", "file", "sha256", "amount"])
    }

    @Test("a tracked clip writes its track as the media followed, the media time, the target and the frames followed")
    func writesTrack() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [
                { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" }, "parent": "screen", "track": { "text": "Total" } },
                { "shape": "rect", "fill": "#FFD43B80", "area": { "text": "Total", "padding": 14 }, "parent": "screen", "track": true } ] } ] }
            """#

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue?.compactMap(\.objectValue))

        // Then
        #expect(clips[0]["track"]?.objectValue?.keys == ["media", "time", "target", "frames"])
        #expect(clips[1]["track"]?.objectValue?.keys == ["media", "time", "target", "frames"])
    }

    @Test("a media clip plays in at its window's start, written as origin, even where the sequence cuts its start")
    func writesOriginOfCutClip() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 } ],
              "clips": [ { "media": "/abs/short.mp4", "at": [-0.75, 2] } ] }
            """#

        // When
        let clip = try #require(try write(document)["clips"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(clip["start"] == .number(0))
        #expect(clip["in"] == .number(0))
        #expect(clip["origin"] == .number(-0.75))
    }

    @Test("a compound clip carries its nested resolved sequence in place of a file")
    func writesCompoundClip() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": {
                "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 } ] } } ] }
            """#

        // When
        let resolved = try write(document)

        // Then
        let nested = try #require(resolved["storyline"]?.arrayValue?.first?.objectValue?["media"]?.objectValue)
        #expect(nested.keys == ["kind", "format", "storyline", "clips", "audio"])
        #expect(nested["storyline"]?.arrayValue?.first?.objectValue?["media"]?.objectValue?["file"] == .string("/abs/run.mp4"))
        #expect(resolved["audio"]?.arrayValue?.first?.objectValue?["media"] == .null)
        #expect(resolved["audio"]?.arrayValue?.first?.objectValue?["nested"]?.arrayValue?.count == 1)
    }

    @Test("audio is every source of sound, with its volume and pan in sequence time")
    func writesAudio() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "media": "/abs/bgm.m4a", "at": 1, "loop": true,
                           "keyframes": [ { "at": 0, "volume": 0.3, "pan": -1 }, { "at": 1, "volume": 0, "pan": 1 } ] } ] }
            """#

        // When
        let resolved = try write(document)

        // Then
        let audio = try #require(resolved["audio"]?.arrayValue)
        let music = try #require(audio.last?.objectValue)
        #expect(resolved["clips"] == .array([]))
        #expect(audio.count == 2)
        #expect(music["place"] == .string("clips[0]"))
        #expect(music["loop"] == .bool(true))
        #expect(music["start"] == .number(1))
        #expect(music["volume"]?.arrayValue?.compactMap { $0.objectValue?["at"] } == [.number(0), .number(1)])
        #expect(music.keys.firstIndex(of: "pan") == music.keys.firstIndex(of: "volume").map { $0 + 1 })
        #expect(music["pan"]?.arrayValue?.compactMap { $0.objectValue?["at"] } == [.number(0), .number(1)])
        #expect(music["pan"]?.arrayValue?.compactMap { $0.objectValue?["value"] } == [.number(-1), .number(1)])
        #expect(audio.first?.objectValue?["pan"]?.arrayValue?.first?.objectValue?["value"] == .number(0))
    }

    @Test("a sound crossfading over a transition writes it as its range and the storyline entry's audio curve")
    func writesCrossfade() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 6 },
                                                 { "media": "/abs/run.mp4", "in": 10, "out": 14, "transition": "mine/same-take" } ] }
            """#

        // When
        let resolved = try write(document)

        // Then
        let audio = try #require(resolved["audio"]?.arrayValue)
        let crossfade = JSONValue.object(JSONObject(members: [
            JSONMember(key: "start", value: .number(3.5)),
            JSONMember(key: "end", value: .number(4.5)),
            JSONMember(key: "audio", value: .string("constant-gain"))
        ]))
        #expect(audio.first?.objectValue?["incoming"] == .null)
        #expect(audio.first?.objectValue?["outgoing"] == crossfade)
        #expect(audio.last?.objectValue?["incoming"] == crossfade)
        #expect(audio.last?.objectValue?["outgoing"] == .null)
    }

    @Test("a shape entry writes its kind, its geometry as written, its outset and its appearance after its id, every key present and null where none")
    func writesShapeEntry() throws {
        // Given
        let document = ##"""
            { "kind": "sequence", "format": { "size": [2412, 5244] },
              "theme": { "shapes": { "outline": { "stroke": { "width": 8, "color": "#ED2929" }, "radius": 18 } } },
              "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
                { "shape": "rect", "style": "outline", "area": [0, 0, 100, 100], "at": [0, 1] },
                { "shape": "path", "points": [[500, 500], [600, 500]], "stroke": { "width": 10, "end": "arrow" }, "at": [0, 1] },
                { "shape": "ellipse", "width": 200, "height": 100, "outset": 10, "fill": "#00000080", "at": [0, 1] },
                { "shape": "rect", "area": [100, 100, 200, 100], "outset": 20, "anchor": "bottom-right", "fill": "accent", "at": [0, 1] } ] }
            """##
        let theme = MergedTheme.base
        let scale = theme.lengthScale(at: 2412)

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue?.compactMap(\.objectValue))

        // Then
        #expect(clips[0].keys == [
            "place", "id", "shape", "area", "width", "height", "points", "closed", "outset", "radius", "trim", "fill",
            "stroke", "shadow", "start", "end", "lane", "storyline", "parent", "size", "position", "anchor", "crop", "mask",
            "trackMatte", "track", "opacity", "scale", "rotation", "blend", "animation"
        ])
        #expect(clips[0]["area"] == keyframes(at: 0, Rectangle(x: 0, y: 0, width: 100, height: 100)))
        #expect(clips[0]["width"] == .null)
        #expect(clips[0]["points"] == .null)
        #expect(clips[0]["closed"] == .null)
        #expect(clips[0]["outset"] == .null)
        #expect(clips[0]["radius"]?.arrayValue?.first?.objectValue?["value"] == .number(18 * scale))
        #expect(clips[0]["fill"] == .null)
        #expect(clips[0]["stroke"] == .object(JSONObject(members: [
            JSONMember(key: "color", value: held(.string("#ED2929FF"))),
            JSONMember(key: "width", value: held(.number(8 * scale))),
            JSONMember(key: "join", value: .string("round")),
            JSONMember(key: "cap", value: .string("butt")),
            JSONMember(key: "start", value: .string("none")),
            JSONMember(key: "end", value: .string("none")),
            JSONMember(key: "dashOffset", value: held(.number(0)))
        ])))
        #expect(clips[0]["shadow"] == .null)
        #expect(clips[0]["size"] == .null)
        #expect(clips[0]["position"] == .null)
        #expect(clips[0]["anchor"] == .null)
        #expect(clips[1]["closed"] == .bool(false))
        #expect(clips[1]["area"] == .null)
        #expect(clips[1]["outset"] == .null)
        #expect(clips[1]["stroke"]?.objectValue?["color"] == held(.string(theme.color("accent").hex)))
        #expect(clips[1]["stroke"]?.objectValue?["end"] == .string("arrow"))
        #expect(clips[1]["radius"] == .null)
        #expect(clips[1]["trim"]?.arrayValue?.first?.objectValue?["value"] == .array([.number(0), .number(1)]))
        #expect(clips[2]["width"]?.arrayValue?.first?.objectValue?["value"] == .number(200))
        #expect(clips[2]["outset"] == held(.number(10 * scale)))
        // An ellipse placed by `width` and `height` keeps its box as written, its outset growing only the outline it
        // draws.
        #expect(clips[2]["size"] == .array([.number(200), .number(100)]))
        #expect(clips[2]["anchor"] == .array([.number(100), .number(50)]))
        #expect(clips[2]["fill"] == held(.string("#00000080")))
        #expect(clips[2]["stroke"] == .null)
        // A named anchor of a shape placed by its area is a point of its area as written, whatever its outset.
        #expect(clips[3]["anchor"] == .array([.number(300), .number(200)]))
    }

    @Test("masks are written after the crop as a list of {geometry, feather, invert, mode}, each number a keyframe list, a box keeping its width, height and position, and null for none")
    func writesMasks() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [3840, 2160] },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 4, "mask": { "shape": "ellipse", "area": [16, 16, 480, 480], "feather": 3 } } ],
              "clips": [
                { "media": "/abs/card.png", "at": [0, 4], "width": 160,
                  "mask": [ { "shape": "rect", "width": 100, "height": 40, "position": [200, 300], "radius": 4, "invert": true, "mode": "intersect" },
                            { "shape": "path", "points": [[0, 0], [10, 0], [5, 10]] } ] },
                { "adjust": "frames/warm", "at": [0, 4], "mask": { "shape": "rect" }, "keyframes": [
                    { "at": 1, "ease": "ease-out", "mask": { "area": [0, 0, 10, 10] } },
                    { "at": 3, "mask": { "area": [0, 0, 20, 20], "feather": 1 } } ] },
                { "title": "a", "style": "title", "at": [0, 4] } ] }
            """#

        // When
        let resolved = try write(document)
        let storyline = try #require(resolved["storyline"]?.arrayValue?.first?.objectValue)
        let clips = try #require(resolved["clips"]?.arrayValue).compactMap(\.objectValue)

        // Then
        for entry in [storyline] + clips {
            let crop = try #require(entry.keys.firstIndex(of: "crop"))
            #expect(Array(entry.keys[crop...].prefix(4)) == ["crop", "mask", "trackMatte", "track"])
        }
        #expect(storyline["mask"] == (try Fixture.json(#"""
            [ { "geometry": { "ellipse": { "rect": [ { "at": 0, "value": [16, 16, 480, 480], "ease": "linear" } ] } },
                "feather": [ { "at": 0, "value": 6, "ease": "linear" } ], "invert": false, "mode": "add" } ]
            """#)))
        #expect(clips[0]["mask"] == (try Fixture.json(#"""
            [ { "geometry": { "rect": { "width": [ { "at": 0, "value": 100, "ease": "linear" } ], "height": [ { "at": 0, "value": 40, "ease": "linear" } ],
                  "position": [ { "at": 0, "value": [200, 300], "ease": "linear" } ], "radius": [ { "at": 0, "value": 4, "ease": "linear" } ] } },
                "feather": [ { "at": 0, "value": 0, "ease": "linear" } ], "invert": true, "mode": "intersect" },
              { "geometry": { "polyline": { "points": [ [ { "at": 0, "value": [0, 0], "ease": "linear" } ], [ { "at": 0, "value": [10, 0], "ease": "linear" } ],
                  [ { "at": 0, "value": [5, 10], "ease": "linear" } ] ], "closed": true } },
                "feather": [ { "at": 0, "value": 0, "ease": "linear" } ], "invert": false, "mode": "add" } ]
            """#)))
        #expect(clips[1]["mask"] == (try Fixture.json(#"""
            [ { "geometry": { "rect": {
                  "rect": [ { "at": 1, "value": [0, 0, 10, 10], "ease": "ease-out" }, { "at": 3, "value": [0, 0, 20, 20], "ease": "linear" } ],
                  "radius": [ { "at": 0, "value": 0, "ease": "linear" } ] } },
                "feather": [ { "at": 3, "value": 2, "ease": "linear" } ], "invert": false, "mode": "add" } ]
            """#)))
        #expect(clips[2]["mask"] == .null)
    }

    // MARK: - Private
    private func write(
        _ document: String,
        presets: PresetTable = Fixture.presets,
        tracker: TrackerTable = Fixture.tracker
    ) throws -> JSONObject {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets,
            ocr: Fixture.ocr,
            languages: nil,
            tracker: tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )
        let text = sut.write(try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: hashes))

        return try #require(try JSONReader().read(text).objectValue)
    }

    // A timed leaf no keyframe moves: one keyframe at the clip's instant.
    private func held(_ value: JSONValue) -> JSONValue {
        .array([.object(JSONObject(members: [
            JSONMember(key: "at", value: .number(0)),
            JSONMember(key: "value", value: value),
            JSONMember(key: "ease", value: .string("linear"))
        ]))])
    }

    private func keyframes(
        at instant: Double,
        _ rectangle: Rectangle
    ) -> JSONValue {
        .array([.object(JSONObject(members: [
            JSONMember(key: "at", value: .number(instant)),
            JSONMember(key: "value", value: .array([rectangle.x, rectangle.y, rectangle.width, rectangle.height].map(JSONValue.number))),
            JSONMember(key: "ease", value: .string("linear"))
        ]))])
    }
}
