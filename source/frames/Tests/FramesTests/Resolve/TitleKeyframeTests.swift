//
//  TitleKeyframeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Titles are sequence clips over `/abs/screen.mp4` in a 1920 by 1080 frame, so theme lengths are output pixels, and each
// is checked by the key tables before it is planned. The theme holds the style `caption`, 40 in `#000000` with a stroke
// 4 wide in `#000000`, `small`, 20 in `#FF0000`, and `wide`, 20 tracked by 100. A glyph is half an em wide and a space
// a quarter.
@Suite("Title keyframe Tests")
struct TitleKeyframeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a keyframe of `character.color` times every run's colour, a theme colour's name read through the theme")
    func timesRunColours() throws {
        // When
        let title = try title(#"""
            { "title": [ { "text": "a " }, { "text": "b", "style": "small" } ], "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "color": "accent" } }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#)

        // Then
        let colors = { (time: Double) in
            title.characters.map { $0.sampled(at: time, as: LookStructureTable.character)["color"]?.color }
        }
        #expect(colors(0) == [Color(written: "#FFD43BFF"), Color(written: "#FFD43BFF")])
        #expect(colors(1) == [Color(written: "#FFFFFFFF"), Color(written: "#FFFFFFFF")])
    }

    @Test("a keyframe that writes only `character.stroke.width` keeps each run's stroke colour from its own style")
    func keepsRunStrokeColour() throws {
        // When
        let title = try title(#"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "stroke": { "width": 2 } } }, { "at": 1, "character": { "stroke": { "width": 6 } } } ] }
            """#)

        // Then
        let stroke = title.characters[0].sampled(at: 0.5, as: LookStructureTable.character)["stroke"]
        #expect(stroke?["width"]?.number == 4)
        #expect(stroke?["color"]?.color == Color(written: "#000000FF"))
    }

    @Test(
        "an attribute that decides faces, shaping or line breaks stops in a keyframe, naming the keyframe",
        arguments: [
            (#""character": { "size": 60 }"#, "clips[0].keyframes[0].character.size"),
            (#""character": { "font": ["Inter"] }"#, "clips[0].keyframes[0].character.font[0]"),
            (#""character": { "weight": "bold" }"#, "clips[0].keyframes[0].character.weight"),
            (#""character": { "italic": true }"#, "clips[0].keyframes[0].character.italic"),
            (#""character": { "kerning": "none" }"#, "clips[0].keyframes[0].character.kerning"),
            (#""character": { "features": { "tnum": 1 } }"#, "clips[0].keyframes[0].character.features.tnum"),
            (#""paragraph": { "align": "right" }"#, "clips[0].keyframes[0].paragraph.align")
        ]
    )
    func refusesStaticAttributeInKeyframe(
        keyframe: String,
        place: String
    ) throws {
        // Given
        let clip = #"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, \#(keyframe) }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#

        // When, Then
        let message = place + " (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"
        let error = #expect(throws: (any Error).self) { try title(clip) }
        #expect(error.map(String.init(describing:)) == message)
    }

    @Test("`null` for a title's `character` in a keyframe stops, since it stands for a leaf")
    func refusesNullCharacter() throws {
        // Given
        let clip = #"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": null }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try title(clip) }
        #expect(error.map(String.init(describing:)) == #"clips[0].keyframes[0].character (keyframe): null stands for a leaf, not for an object or a list"#)
    }

    @Test("a resolved run carries its colour, stroke, baseline shift, highlight and underline timed, and reads back as written")
    func roundTripsRuns() throws {
        // Given
        let text = try resolvedText(##"""
            { "title": "a b", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "padding": [2, 4] }, "underline": true },
              "keyframes": [ { "at": 0, "character": { "color": "accent", "baselineShift": 0, "highlight": { "radius": 0 } }, "ease": "ease-in" },
                             { "at": 1, "character": { "color": "#FFFFFF", "baselineShift": 10, "highlight": { "radius": 6 } } } ] }
            """##)
        let writer = ResolvedValueWriter()
        let reader = ResolvedValueReader()

        // When
        let read = try reader.runs(PlacedJSONValue(writer.runs(text.runs), place: .root, kind: "title"))

        // Then
        let run = try #require(text.runs.first)
        #expect(run.color == .track([
            Keyframe(at: 0, value: .color(Color(written: "#FFD43B")), ease: .easeIn),
            Keyframe(at: 1, value: .color(Color(written: "#FFFFFF")))
        ]))
        #expect(run.highlight?.rects.count == 1)
        #expect(run.highlight?.padding == .track([Keyframe(at: 0, value: .numbers([2, 4]))]))
        #expect(read == text.runs)
    }

    @Test("`underline: true` takes its width and offset from the face's `post` underline at the run's size, and the run's colour")
    func takesUnderlineFromFace() throws {
        // When
        let text = try resolvedText(#"""
            { "title": "a", "style": "caption", "position": [400, 225], "character": { "underline": true },
              "keyframes": [ { "at": 0, "character": { "color": "#FF0000" } }, { "at": 1, "character": { "color": "#FFFFFF" } } ] }
            """#)

        // Then
        let underline = try #require(text.runs.first?.underline)
        #expect(underline.width == .track([Keyframe(at: 0, value: .number(2))]))
        #expect(underline.offset == .track([Keyframe(at: 0, value: .number(4))]))
        #expect(underline.color == text.runs.first?.color)
        #expect(underline.rects.map(\.width) == [20])
    }

    @Test("a stroke without a colour takes the `text` colour, and a highlight without one the `background` colour, no padding and no radius")
    func defaultsStrokeAndHighlight() throws {
        // When
        let title = try title(#"""
            { "title": "a", "style": "small", "position": [400, 225],
              "character": { "stroke": { "width": 2 }, "highlight": { "radius": 0 } } }
            """#)

        // Then
        let character = title.characters[0].sampled(at: 0, as: LookStructureTable.character)
        #expect(character["stroke"]?["color"]?.color == MergedTheme.base.color("text"))
        #expect(character["highlight"]?["color"]?.color == MergedTheme.base.color("background"))
        #expect(character["highlight"]?["padding"]?.numbers == [0, 0])
        #expect(character["baselineShift"]?.number == 0)
    }

    @Test("evaluation raises a run's glyphs by its baseline shift at each instant")
    func raisesGlyphsByBaselineShift() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "baselineShift": 0 } }, { "at": 1, "character": { "baselineShift": 10 } } ] }
            """#)
        let run = try #require(text.runs.first)

        // When
        let still = Point(x: 0, y: 0)
        let sut = DrawnGlyphRun(
            run: run,
            at: 0.5,
            moves: run.glyphs.map { _ in still },
            pieceMove: PieceMove(start: still, end: still)
        )

        // Then
        #expect(sut.glyphs.map(\.y) == run.glyphs.map { $0.y - 5 })
    }

    @Test(
        "a title breaks its lines at the largest tracking its keyframes reach, an ease's overshoot included",
        arguments: [("linear", 1), ("back-out", 2)]
    )
    func breaksAtWidestTracking(
        ease: String,
        lineCount: Int
    ) throws {
        // When
        let title = try title(#"""
            { "title": "aa bb", "style": "caption", "position": [400, 225], "width": 100,
              "keyframes": [ { "at": 0, "character": { "tracking": 0 }, "ease": "\#(ease)" }, { "at": 1, "character": { "tracking": 60 } } ] }
            """#)

        // Then
        #expect(title.layout.lineCount == lineCount)
        #expect(title.layout.runs[0].glyphs.prefix(2).map(\.x) == [0, 20])
    }

    @Test("a `null` tracking keyframe is each run's own tracking, so each run steps from its own")
    func stepsEachRunFromItsOwnTracking() throws {
        // When
        let title = try title(#"""
            { "title": [ { "text": "ab" }, { "text": "cd", "style": "wide" } ], "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "tracking": null } }, { "at": 1, "character": { "tracking": 50 } } ] }
            """#)

        // Then
        let steps = { (time: Double) in
            title.trackingSteps.map { $0.sampled(at: time, as: .leaf(.length(.any))).number }
        }
        #expect(steps(0) == [0, 0])
        #expect(steps(1) == [2, -1])
    }

    @Test("a tracking that takes one value adds no steps, and the title carries no lines")
    func carriesNoLinesForStaticTracking() throws {
        // When
        let text = try resolvedText(#"""
            { "title": "ab", "style": "wide", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "tracking": 100 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)

        // Then
        #expect(text.lines == nil)
        #expect(text.runs[0].tracking == .off)
    }

    @Test("evaluation moves a centred title's glyphs by the tracking at an instant, and its box widens about its centre")
    func movesGlyphsByTracking() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "ab", "style": "caption", "position": [400, 225], "paragraph": { "align": "center" },
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)

        // When
        let moves = text.glyphMoves(at: 0.5)
        let box = text.box(at: 0.5)
        let sut = GlyphsItem(text: text, at: 0.5)

        // Then
        #expect(text.width == nil)
        #expect(moves == [[Point(x: -1, y: 0), Point(x: 1, y: 0)]])
        #expect(box == Rectangle(x: -1, y: 0, width: 42, height: 40))
        #expect(sut.size == Size(width: 42, height: 40))
        #expect(sut.runs[0].glyphs.map(\.x) == [0, 22])
    }

    @Test("evaluation keeps a title with a width at its width, and places each line again inside it by `align`")
    func keepsWidthWhileTracking() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "ab", "style": "caption", "position": [400, 225], "width": 100, "paragraph": { "align": "right" },
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)

        // When
        let moves = text.glyphMoves(at: 0.5)
        let box = text.box(at: 0.5)

        // Then
        #expect(text.width == 100)
        #expect(moves == [[Point(x: -2, y: 0), Point(x: 0, y: 0)]])
        #expect(box == Rectangle(x: 0, y: 0, width: 100, height: 40))
    }

    @Test("evaluation moves each line below the first by the change in line height, keeping the box's top edge")
    func movesLinesByLineHeight() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "a\nb", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "paragraph": { "lineHeight": 50 } }, { "at": 1, "paragraph": { "lineHeight": 70 } } ] }
            """#)

        // When
        let box = text.box(at: 0.5)
        let sut = GlyphsItem(text: text, at: 0.5)

        // Then
        #expect(text.lines?.map(\.baseline) == [32, 82])
        #expect(text.size.height == 90)
        #expect(box == Rectangle(x: 0, y: 0, width: 20, height: 100))
        #expect(sut.runs.first?.glyphs.first?.y == 32)
        #expect(sut.runs.last?.glyphs.first?.y == 92)
    }

    @Test("a `null` line height in a keyframe is the merged line height, the default where no layer gives one")
    func takesMergedLineHeightForNull() throws {
        // When
        let text = try resolvedText(#"""
            { "title": "a\nb", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "paragraph": { "lineHeight": null } }, { "at": 1, "paragraph": { "lineHeight": 70 } } ] }
            """#)

        // Then
        let lineHeight = { (time: Double) in text.lineHeight.sampled(at: time, as: .leaf(.length(.any))).number }
        #expect(lineHeight(0) == 50)
        #expect(lineHeight(1) == 70)
        #expect(text.lines != nil)
    }

    @Test("a background's keyframed padding grows the title's box around its text box, and its background fills it")
    func growsBoxByPadding() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "ab", "style": "caption", "position": [400, 225], "paragraph": { "background": { "color": "#FF0000" } },
              "keyframes": [ { "at": 0, "paragraph": { "background": { "padding": [0, 0] } } },
                             { "at": 1, "paragraph": { "background": { "padding": [10, 20] } } } ] }
            """#)

        // When
        let box = text.box(at: 1)
        let sut = GlyphsItem(text: text, at: 1)

        // Then
        #expect(text.size == Size(width: 40, height: 40))
        #expect(text.lines == nil)
        #expect(box == Rectangle(x: -20, y: -10, width: 80, height: 60))
        #expect(sut.size == Size(width: 80, height: 60))
        #expect(sut.background?.rectangle == Rectangle(x: 0, y: 0, width: 80, height: 60))
        #expect(sut.background?.color == Color(written: "#FF0000FF"))
        #expect(sut.runs[0].glyphs.first.map { Point(x: $0.x, y: $0.y) } == Point(x: 20, y: 42))
    }

    @Test("a title's box grown at an instant keeps its text box where resolve placed it in the frame")
    func placesGrownBox() throws {
        // Given
        let document = document(#"""
            { "title": "ab", "style": "caption", "anchor": "top-left", "position": [400, 225],
              "paragraph": { "background": { "color": "#FF0000" } },
              "keyframes": [ { "at": 0, "paragraph": { "background": { "padding": [0, 0] } } },
                             { "at": 1, "paragraph": { "background": { "padding": [10, 20] } } } ] }
            """#)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())

        // When
        let list = Evaluator().displayList(of: resolved, at: 1)

        // Then
        let item = try #require(list.items.first { item in
            guard case .glyphs = item.content else { return false }

            return true
        })
        #expect(item.transform.apply(to: Point(x: 0, y: 0)) == Point(x: 380, y: 215))
        #expect(item.transform.apply(to: Point(x: 20, y: 10)) == Point(x: 400, y: 225))
    }

    @Test("evaluation draws highlight and underline pieces over their glyphs where they are at an instant")
    func movesPiecesWithGlyphs() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "ab", "style": "caption", "position": [400, 225], "paragraph": { "align": "center" },
              "character": { "highlight": { "color": "#FF0000", "padding": [2, 4] }, "underline": true },
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)

        // When
        let sut = GlyphsItem(text: text, at: 0.5)

        // Then
        let run = try #require(sut.runs.first)
        #expect(run.highlight == DrawnHighlight(
            rects: [Rectangle(x: -4, y: -2, width: 50, height: 44)],
            radius: 0,
            color: Color(written: "#FF0000FF"),
            bands: nil
        ))
        #expect(run.underline == DrawnUnderline(
            rects: [Rectangle(x: 0, y: 36, width: 42, height: 2)],
            color: Color(written: "#000000FF"),
            bands: nil
        ))
    }

    // MARK: - Private
    private func resolvedText(_ clip: String) throws -> ResolvedText {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))
        let clips = try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips
        guard case let .title(text) = clips.first?.content else {
            Issue.record("the clip is a title")
            return ResolvedText(size: Size(width: 0, height: 0), background: nil, runs: [])
        }

        return text
    }

    private func title(_ clip: String) throws -> TitlePlan {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))

        return try #require(plan.clips[0].title)
    }

    private func document(_ clip: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "colors": { "accent": "#FFD43B" },
                         "styles": { "caption": { "size": 40, "color": "#000000", "stroke": { "width": 4, "color": "#000000" } },
                                     "small": { "size": 20, "color": "#FF0000" },
                                     "wide": { "size": 20, "tracking": 100 } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip.dropLast(1)), "at": [0, 2] } ] }
            """#
    }
}
