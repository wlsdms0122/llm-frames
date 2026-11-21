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

    @Test("a look value outside its domain written statically on a clip stops where it is written, as in a keyframe")
    func refusesStaticValueOutsideDomain() throws {
        // Given
        let written = #"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "color": "#FF0000", "padding": [-4, 0] } } }
            """#
        let keyframed = #"""
            { "title": "a", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "color": "#FF0000" } },
              "keyframes": [ { "at": 0, "character": { "highlight": { "padding": [-4, 0] } } } ] }
            """#

        // When
        let writtenError = #expect(throws: ModelError.self) { try title(written) }
        let keyframedError = #expect(throws: LookError.self) { try title(keyframed) }

        // Then
        #expect(writtenError == .outsideDomain(
            place: Place.root.appending(key: "clips").appending(index: 0)
                .appending(key: "character").appending(key: "highlight").appending(key: "padding").appending(index: 0),
            kind: "highlight",
            value: -4,
            domain: .nonNegative
        ))
        #expect(keyframedError == .outsideDomain(
            place: Place.root.appending(key: "clips").appending(index: 0).appending(key: "keyframes").appending(index: 0)
                .appending(key: "character").appending(key: "highlight").appending(key: "padding").appending(index: 0),
            value: -4,
            domain: .nonNegative
        ))
        #expect(writtenError?.description == "clips[0].character.highlight.padding[0] (highlight): -4 is not 0 or more")
        #expect(keyframedError?.description == "clips[0].keyframes[0].character.highlight.padding[0]: -4 is not 0 or more")
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
            factor: 1,
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

    @Test("a resolved title's lines carry their extent, range, characters and hanging spaces, and read back as written")
    func roundTripsLines() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "ab \ncd", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)
        let writer = ResolvedValueWriter()
        let reader = ResolvedValueReader()

        // When
        let read = try reader.text(PlacedJSONValue(writer.text(text), place: .root, kind: "title"))

        // Then
        let cluster = { (run: Int, first: Int, count: Int, range: Range<Int>, advance: Double) in
            PlacedCluster(glyphs: GlyphRange(run: run, first: first, count: count), range: range, advance: advance)
        }
        #expect(text.lines == [
            PlacedLine(
                width: 40,
                baseline: 32,
                ascent: 32,
                descent: 8,
                range: 0..<2,
                clusters: [cluster(0, 0, 1, 0..<1, 20), cluster(0, 1, 1, 1..<2, 20)],
                hanging: [cluster(0, 2, 1, 2..<3, 10)]
            ),
            PlacedLine(
                width: 40,
                baseline: 82,
                ascent: 32,
                descent: 8,
                range: 4..<6,
                clusters: [cluster(1, 0, 1, 4..<5, 20), cluster(1, 1, 1, 5..<6, 20)],
                hanging: []
            )
        ])
        #expect(read == text)
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

    @Test("a tracking that takes one value adds no steps, and the title still carries its lines")
    func carriesLinesForStaticTracking() throws {
        // When
        let text = try resolvedText(#"""
            { "title": "ab", "style": "wide", "position": [400, 225],
              "keyframes": [ { "at": 0, "character": { "tracking": 100 } }, { "at": 1, "character": { "tracking": 100 } } ] }
            """#)

        // Then
        #expect(text.lines.count == 1)
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
        let sut = GlyphsItem(text: text, factor: 1, at: 0.5)

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
        let sut = GlyphsItem(text: text, factor: 1, at: 0.5)

        // Then
        #expect(text.lines.map(\.baseline) == [32, 82])
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
        #expect(text.lines.count == 2)
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
        let sut = GlyphsItem(text: text, factor: 1, at: 1)

        // Then
        #expect(text.size == Size(width: 40, height: 40))
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
        let sut = GlyphsItem(text: text, factor: 1, at: 0.5)

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

    @Test("a title's reach holds its highlights and underlines, and its box grown by half its widest stroke")
    func boundsDecorations() throws {
        // Given
        let text = try resolvedText(#"""
            { "title": "ab", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "color": "#FF0000", "padding": [2, 4] }, "underline": { "offset": 10 } } }
            """#)

        // When
        let sut = GlyphsItem(text: text, factor: 1, at: 0)

        // Then
        #expect(sut.filledRects() == [
            Rectangle(x: 0, y: 0, width: 40, height: 40),
            Rectangle(x: -4, y: -2, width: 48, height: 44),
            Rectangle(x: 0, y: 42, width: 40, height: 2)
        ])
        #expect(sut.drawnBounds(carriedBy: .identity) == Rectangle(x: -4, y: -2, width: 48, height: 46))
    }

    @Test("an animation over a title whose line height opens offsets it by its box then and scales it about its anchor point, which stays")
    func animatesBoxAtInstant() throws {
        // Given
        let resolved = try resolvedClip(#"""
            { "title": "a\nb", "style": "caption", "position": [400, 225],
              "keyframes": [ { "at": 0, "paragraph": { "lineHeight": 50 } }, { "at": 1, "paragraph": { "lineHeight": 100 } } ] }
            """#)
        let clip = animated(resolved, by: Motion(values: [.scale: 2, .y: 1]))
        guard case let .title(text) = clip.content else {
            Issue.record("the clip is a title")
            return
        }

        // When
        let items = ClipEvaluator().items(
            of: clip,
            in: ClipSpace(frame: Rectangle(x: 0, y: 0, width: 1920, height: 1080)),
            picture: nil,
            trackMatte: nil,
            compositing: .encoded,
            seed: 0,
            at: 1
        )

        // Then
        // The static box is w by h about its centre at (400, 225), and at 1 it is 50 taller below. Scaled by 2 about
        // that centre its top left lies at (400 - w, 225 - h), and the offset moves it down by the box's height then.
        let item = try #require(items.first)
        guard case let .glyphs(glyphs) = item.content else {
            Issue.record("the item draws glyphs")
            return
        }
        #expect(glyphs.size == Size(width: text.size.width, height: text.size.height + 50))
        #expect(item.transform.apply(to: Point(x: 0, y: 0)) == Point(x: 400 - text.size.width, y: 275))
    }

    @Test("a child of a title whose padding grows follows the title's box at that instant")
    func carriesChildByBoxAtInstant() throws {
        // Given
        let document = document(#"""
            { "id": "t", "title": "ab", "style": "caption", "anchor": "top-left", "position": [400, 225], "at": [0, 2],
              "paragraph": { "background": { "color": "#FF0000" } },
              "keyframes": [ { "at": 0, "paragraph": { "background": { "padding": [0, 0] } } },
                             { "at": 1, "paragraph": { "background": { "padding": [10, 20] } } } ] },
            { "title": "c", "style": "caption", "parent": "t", "anchor": "top-left", "position": [0, 0] }
            """#)
        let resolved = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())

        // When
        let list = Evaluator().displayList(of: resolved, at: 1)

        // Then
        let items = list.items.filter { item in
            guard case .glyphs = item.content else { return false }

            return true
        }
        #expect(items.count == 2)
        #expect(items.last?.transform.apply(to: Point(x: 0, y: 0)) == Point(x: 380, y: 215))
    }

    // MARK: - Private
    // `clip` with an entrance that holds `motion` over its whole window.
    private func animated(
        _ clip: ResolvedClip,
        by motion: Motion
    ) -> ResolvedClip {
        let keys = [SpanKey(t: 0, values: motion.values), SpanKey(t: 1, values: motion.values)]
        let entrance = AnimationSpan(length: clip.end - clip.start, span: Span(ease: .linear, keys: keys))

        return ResolvedClip(
            place: clip.place,
            id: clip.id,
            content: clip.content,
            start: clip.start,
            end: clip.end,
            lane: clip.lane,
            storyline: clip.storyline,
            parent: clip.parent,
            box: clip.box,
            crop: clip.crop,
            mask: clip.mask,
            trackMatte: clip.trackMatte,
            track: clip.track,
            opacity: clip.opacity,
            scale: clip.scale,
            rotation: clip.rotation,
            blend: clip.blend,
            animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil, units: nil)
        )
    }

    private func resolvedClip(_ clip: String) throws -> ResolvedClip {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))

        return try #require(try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips.first)
    }

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
