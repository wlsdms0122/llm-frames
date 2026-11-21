//
//  TitleGroupTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// Titles are sequence clips over `/abs/screen.mp4` from 0 to 2 in a 1920 by 1080 frame, so theme lengths are output
// pixels. The style `caption` is 40 with a stroke 4 wide, so a glyph is 20 wide, a space 10, and a line reaches 32
// above its baseline and 8 below. Each title is set by word, and its animation replaced by the spans a test gives.
@Suite("Title group Tests")
struct TitleGroupTests {
    // MARK: - Property
    private static let frame = Rectangle(x: 0, y: 0, width: 1920, height: 1080)

    private let sut = ClipEvaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a title by word draws one picture of a list the frame's size: its background, then each layer's pass over its units in reading order")
    func drawsGroup() throws {
        // Given
        let clip = try resolvedClip(#"{ "title": "ab cd", "style": "caption", "position": [400, 225] }"#)
        let byWord = animated(clip, entrance: fade, stagger: 0.1)
        let whole = animated(clip, entrance: fade, stagger: nil)

        // When
        let items = sut.items(of: byWord, in: space, picture: nil, trackMatte: nil, compositing: .encoded, seed: 7, at: SampleTime(1))
        let single = try #require(sut.items(of: whole, in: space, picture: nil, trackMatte: nil, compositing: .encoded, seed: 7, at: SampleTime(1)).first)

        // Then
        let group = try #require(items.first)
        #expect(items.count == 1)
        #expect(group.transform == .identity)
        #expect(group.opacity == single.opacity)
        guard case let .picture(picture) = group.content, case let .displayList(list) = picture.source else {
            Issue.record("the group is a picture of a nested list")
            return
        }
        guard case let .glyphs(glyphs) = single.content else {
            Issue.record("the title draws glyphs")
            return
        }
        #expect(picture.rectangle == Self.frame)
        #expect(picture.destination == Self.frame)
        #expect(list.size == Size(width: 1920, height: 1080))
        #expect(list.seed == 7)
        #expect(list.items.map(\.origin) == Array(repeating: ItemOrigin(clip: clip), count: 9))
        #expect(list.items.map { self.glyphs(of: $0)?.unit } == [nil] + (0..<4).flatMap { _ in [0, 1] })
        #expect(list.items.map(\.transform) == Array(repeating: single.transform, count: 9))
        #expect(list.items.map { layer(of: $0) } == [GlyphLayer?.none] + GlyphLayer.allCases.flatMap { [$0, $0] })
        // "ab" draws the space after it.
        let counts = list.items.map { self.glyphs(of: $0)?.runs.flatMap(\.glyphs).count ?? -1 }
        #expect(counts == [0, 3, 2, 3, 2, 3, 2, 3, 2])
        #expect(self.glyphs(of: list.items[7])?.runs.first?.glyphs == Array(glyphs.runs[0].glyphs[0..<3]))
        #expect(self.glyphs(of: list.items[8])?.runs.first?.glyphs == Array(glyphs.runs[0].glyphs[3..<5]))
    }

    @Test("each unit's reveal wipes what it draws, its glyphs and their stroke, on its own schedule, and the background shows whole")
    func revealsEachUnit() throws {
        // Given
        let wipe = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.reveal: 0]), SpanKey(t: 1, values: [.reveal: 1])])
        let clip = try resolvedClip(#"{ "title": "ab cd", "style": "caption", "position": [400, 225] }"#)
        let text = try title(of: clip)

        // When
        let list = try group(
            of: animated(clip, entrance: AnimationSpan(length: 0.5, span: wipe), stagger: 0.5),
            at: 0.25
        )

        // Then
        // Each unit's box is its glyph box grown by 2 for half its stroke: "ab" from 0 to 40 and "cd" from 50 to 90,
        // each from -32 to 8 about the baseline at 32. "ab" also draws the space after it, so its reveal wipes 0 to 50
        // grown by 2.
        let first = text.unitBox(of: 0, at: SampleTime(0.25))
        let second = text.unitBox(of: 1, at: SampleTime(0.25))
        #expect(first == Rectangle(x: -2, y: -2, width: 44, height: 44))
        #expect(second == Rectangle(x: 48, y: -2, width: 44, height: 44))
        #expect(list.items[0].reveal == nil)
        #expect(list.items[1].reveal == Rectangle(x: -2, y: -2, width: 27, height: 44))
        #expect(list.items[2].reveal == Rectangle(x: 48, y: -2, width: 0, height: 44))
    }

    @Test("a unit fully revealed is not cut, and one entering wipes its glyphs, their stroke and its part of the highlight, which its box holds")
    func leavesRevealedUnitWhole() throws {
        // Given
        let wipe = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.reveal: 0]), SpanKey(t: 1, values: [.reveal: 1])])
        let clip = try resolvedClip(#"""
            { "title": "ab cd", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "color": "#FF0000", "padding": [4, 10] } } }
            """#)
        let text = try title(of: clip)

        // When
        let list = try group(
            of: animated(clip, entrance: AnimationSpan(length: 0.5, span: wipe), stagger: 0.5),
            at: 0.75
        )

        // Then
        // "ab" has entered, and "cd" is half way. "cd", from 50 to 90 and from 0 to 40, draws 2 past it for its stroke,
        // and its part of the piece cut to its band, with the highlight's padding of 4 above and below and 10 past the
        // piece's end at 90. Its box holds both.
        let second = text.unitBox(of: 1, at: SampleTime(0.75))
        let carried = try #require(highlight(of: list.items[2]))
        let band = try #require(carried.bands?.first)
        let piece = try #require(carried.rects.first)
        let part = Rectangle(
            x: max(band.lowerBound, piece.x),
            y: piece.y,
            width: min(band.upperBound, piece.maxX) - max(band.lowerBound, piece.x),
            height: piece.height
        )
        #expect(second == Rectangle(x: 48, y: -4, width: 52, height: 48))
        #expect(second.union(part) == second)
        #expect(list.items[1].reveal == nil)
        #expect(list.items[2].reveal == Rectangle(x: 48, y: -4, width: 26, height: 48))
    }

    @Test(
        "a unit entering under a title scaled apart along its axes wipes its stroke where it reaches along each, and shows whole at rest",
        arguments: [0.1, 0.25, 0.4]
    )
    func wipesStrokeUnderTitleScale(at time: Double) throws {
        // Given
        let wipe = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.reveal: 0]), SpanKey(t: 1, values: [.reveal: 1])])
        let clip = try resolvedClip(#"{ "title": "ab cd", "style": "caption", "position": [400, 225], "scale": [2, 1] }"#)
        let animation = animated(clip, entrance: AnimationSpan(length: 0.5, span: wipe), stagger: 0.5)

        // When
        let entering = try group(of: animation, at: time)
        let resting = try group(of: animation, at: 1.5)

        // Then
        // "ab" and the space it draws lie in 0 to 50 across and 0 to 40 down. Its stroke, 4 at the title's scale factor
        // of root 2, is drawn 4 root 2 wide in output pixels, so it reaches root 2 across and 2 root 2 down in the
        // title's text box, scaled 2 across and 1 down.
        let reveal = try #require(entering.items[1].reveal)
        let across = 2.squareRoot()
        let down = 2 * 2.squareRoot()
        #expect(abs(reveal.x + across) < 1e-9)
        #expect(abs(reveal.y + down) < 1e-9)
        #expect(abs(reveal.height - (40 + 2 * down)) < 1e-9)
        #expect(abs(reveal.width - (50 + 2 * across) * time / 0.5) < 1e-9)
        #expect(resting.items[1].reveal == nil)
    }

    @Test(
        "a unit entering under a parent at half scale wipes its stroke where it reaches, and shows whole at rest",
        arguments: [0.1, 0.25, 0.4]
    )
    func wipesStrokeUnderParentScale(at time: Double) throws {
        // Given
        let wipe = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.reveal: 0]), SpanKey(t: 1, values: [.reveal: 1])])
        let clip = try resolvedClip(#"{ "title": "ab cd", "style": "caption", "position": [400, 225] }"#)
        let animation = animated(clip, entrance: AnimationSpan(length: 0.5, span: wipe), stagger: 0.5)
        let parent = ClipSpace(frame: Self.frame, transform: AffineTransform(scale: 0.5, about: Point(x: 0, y: 0)))

        // When
        let entering = try group(of: animation, in: parent, at: time)
        let resting = try group(of: animation, in: parent, at: 1.5)

        // Then
        // A title keeps its size under a parent, so its stroke, 4 wide, reaches 2 past "ab" and the space it draws,
        // which lie in 0 to 50 across and 0 to 40 down.
        let reveal = try #require(entering.items[1].reveal)
        #expect(abs(reveal.x + 2) < 1e-9)
        #expect(abs(reveal.y + 2) < 1e-9)
        #expect(abs(reveal.height - 44) < 1e-9)
        #expect(abs(reveal.width - 54 * time / 0.5) < 1e-9)
        #expect(resting.items[1].reveal == nil)
    }

    @Test("a highlighted word enters with its word, carrying its part of the piece drawn whole and cut to its band")
    func carriesHighlightWithWord() throws {
        // Given
        let slide = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 1]), SpanKey(t: 1, values: [.x: 0])])
        let clip = try resolvedClip(#"""
            { "title": "ab cd", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "color": "#FF0000" } } }
            """#)
        let text = try title(of: clip)
        let title = try #require(sut.items(
            of: animated(clip, entrance: nil, stagger: nil),
            in: space,
            picture: nil,
            trackMatte: nil,
            compositing: .encoded,
            seed: 0,
            at: SampleTime(0.25)
        ).first)

        // When
        let list = try group(
            of: animated(clip, entrance: AnimationSpan(length: 0.5, span: slide), stagger: 0.5),
            at: 0.25
        )

        // Then
        // The piece runs under both words, 0 to 90, and the second word starts at 50.
        let piece = Rectangle(x: 0, y: 0, width: 90, height: 40)
        let red = Color(written: "#FF0000")
        let origin = Point(x: 0, y: 0)
        #expect(highlight(of: list.items[1]) == DrawnHighlight(rects: [piece], radius: 0, color: red, bands: [0...50]))
        #expect(highlight(of: list.items[2]) == DrawnHighlight(rects: [piece], radius: 0, color: red, bands: [50...90]))
        #expect(list.items[1].transform.apply(to: origin) == title.transform.apply(to: Point(
            x: text.unitBox(of: 0, at: SampleTime(0.25)).width / 2,
            y: 0
        )))
        #expect(list.items[2].transform.apply(to: origin) == title.transform.apply(to: Point(
            x: text.unitBox(of: 1, at: SampleTime(0.25)).width,
            y: 0
        )))
    }

    @Test("a highlight broken over two lines leaves each piece to the words of its line")
    func carriesPiecesOnBothLines() throws {
        // Given
        let clip = try resolvedClip(#"""
            { "title": "ab cd ef", "style": "caption", "position": [400, 225], "width": 100,
              "character": { "highlight": { "color": "#FF0000" } } }
            """#)

        let whole = try #require(sut.items(
            of: animated(clip, entrance: fade, stagger: nil),
            in: space,
            picture: nil,
            trackMatte: nil,
            compositing: .encoded,
            seed: 0,
            at: SampleTime(1)
        ).first)
        let pieces = glyphs(of: whole)?.runs.compactMap { $0.highlight?.rects.first } ?? []

        // When
        let list = try group(of: animated(clip, entrance: fade, stagger: 0.1), at: 1)

        // Then
        // "ab cd" sets the first line and "ef" the second, and "cd" starts 50 into the first line's piece.
        let first = try #require(pieces.first)
        let second = try #require(pieces.last)
        #expect(pieces.count == 2)
        #expect(list.items[1...3].map { highlight(of: $0)?.rects } == [[first], [first], [second]])
        #expect(list.items[1...3].map { highlight(of: $0)?.bands } == [
            [first.x...first.x + 50],
            [first.x + 50...first.maxX],
            [second.x...second.maxX]
        ])
    }

    @Test("every glyph of a title by word is drawn by one unit, a line's hanging space by its last unit, whose extent holds it")
    func drawsHangingSpaceByLastUnit() throws {
        // Given
        let clip = try resolvedClip(#"{ "title": "ab cd ", "style": "caption", "position": [400, 225] }"#)

        // When
        let list = try group(of: animated(clip, entrance: fade, stagger: 0.1), at: 1)

        // Then
        let fills = list.items.suffix(2).compactMap { glyphs(of: $0) }
        #expect(fills.map { $0.runs.flatMap(\.glyphs).count } == [3, 3])
        #expect(fills.map(\.extent) == [
            Rectangle(x: 0, y: 0, width: 50, height: 40),
            Rectangle(x: 50, y: 0, width: 50, height: 40)
        ])
        #expect(glyphs(of: list.items[0])?.extent == Rectangle(x: 0, y: 0, width: 100, height: 40))
    }

    @Test("a title by word with no character draws one item of every step, as a title not animated by unit")
    func drawsTitleWithoutUnitAsOne() throws {
        // Given
        let clip = try resolvedClip(#"{ "title": "  ", "style": "caption", "position": [400, 225] }"#)
        let text = try title(of: clip)

        // When
        let items = sut.items(
            of: animated(clip, entrance: fade, stagger: 0.1),
            in: space,
            picture: nil,
            trackMatte: nil,
            compositing: .encoded,
            seed: 0,
            at: SampleTime(1)
        )

        // Then
        #expect(text.units == [])
        #expect(items.count == 1)
        #expect(items.first.flatMap { glyphs(of: $0) }?.layer == nil)
        #expect(items.first.flatMap { glyphs(of: $0) } != nil)
    }

    @Test("the loop's reveal cuts the whole title in its box: the background and each resting unit alike")
    func revealsLoopOnTitle() throws {
        // Given
        let keys = [SpanKey(t: 0, values: [.reveal: 0.5]), SpanKey(t: 1, values: [.reveal: 0.5])]
        let half = Span(ease: .linear, keys: keys)
        let clip = try resolvedClip(#"{ "title": "ab cd", "style": "caption", "position": [400, 225] }"#)
        let animation = { (stagger: Double?) in
            self.animated(clip, entrance: self.fade, loop: AnimationSpan(length: 1, span: half), stagger: stagger)
        }
        let title = try #require(
            sut.items(of: animation(nil), in: space, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: SampleTime(1)).first
        )

        // When
        let list = try group(of: animation(0.1), at: 1)

        // Then
        // The title draws -2 to 92 with its stroke, so the loop shows -2 to 45: all of "ab" and none of "cd".
        let reveal = try #require(title.reveal)
        #expect(reveal == Rectangle(x: -2, y: -2, width: 47, height: 44))
        #expect(list.items.map(\.reveal) == Array(repeating: reveal, count: 9))
    }

    @Test("a title's group reads back as written, each unit's item with its layer and its bands")
    func readsGroupBack() throws {
        // Given
        let clip = try resolvedClip(#"""
            { "title": "ab cd", "style": "caption", "position": [400, 225],
              "character": { "highlight": { "color": "#FF0000" }, "underline": true } }
            """#)
        let list = DisplayList(
            size: Size(width: 1920, height: 1080),
            background: Color(written: "#000000"),
            colorSpace: .srgb,
            seed: 0,
            items: sut.items(of: animated(clip, entrance: fade, stagger: 0.1), in: space, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: SampleTime(0.2))
        )

        // When
        let read = try DisplayListReader().read(DisplayListWriter().write(list))

        // Then
        #expect(read == list)
    }

    @Test("a title's units cover what they draw, the spaces after their words included, and its background item only its background, or nothing")
    func flattensGroup() throws {
        // Given
        let plain = try resolvedClip(#"{ "title": "ab cd", "style": "caption", "position": [400, 225] }"#)
        let boxed = try resolvedClip(#"""
            { "title": "ab cd", "style": "caption", "position": [400, 225],
              "paragraph": { "background": { "color": "#FFFFFF" } } }
            """#)
        let flattener = DisplayListFlattener()
        let flattened = { (clip: ResolvedClip) in
            try flattener.items(of: DisplayList(
                size: Size(width: 1920, height: 1080),
                background: Color(written: "#00000000"),
                seed: 0,
                items: self.sut.items(
                    of: self.animated(clip, entrance: self.fade, stagger: 0.1),
                    in: self.space,
                    picture: nil,
                    trackMatte: nil,
                    compositing: .encoded,
                    seed: 0,
                    at: SampleTime(1)
                )
            ))
        }
        // The title's box, 90 wide, is centred on (400, 225): "cd" starts 50 from its left edge, and the space between
        // the words, 40 to 50, is drawn by "ab".
        let gap = Point(x: 400, y: 225)
        let word = Point(x: 400 + 15, y: 225)

        // When
        let plainItems = try flattened(plain)
        let boxedItems = try flattened(boxed)

        // Then
        // The background item of a title with no background is reported and covers nothing.
        #expect(plainItems.count == 9)
        #expect(plainItems[0].coverage.bounds == nil)
        #expect(plainItems.filter { $0.coverage.contains(gap) }.count == 4)
        #expect(plainItems.filter { $0.coverage.contains(word) }.count == 4)
        #expect(boxedItems.count == 9)
        #expect(boxedItems.filter { $0.coverage.contains(gap) }.count == 5)
        #expect(boxedItems.allSatisfy { $0.origin == ItemOrigin(clip: boxed) })
    }

    // MARK: - Private
    private var space: ClipSpace {
        ClipSpace(frame: Self.frame)
    }

    private var fade: AnimationSpan {
        let keys = [SpanKey(t: 0, values: [.opacity: 0]), SpanKey(t: 1, values: [.opacity: 1])]

        return AnimationSpan(length: 0.25, span: Span(ease: .linear, keys: keys))
    }

    private func group(
        of clip: ResolvedClip,
        in space: ClipSpace? = nil,
        at time: Double
    ) throws -> DisplayList {
        let item = try #require(
            sut.items(of: clip, in: space ?? self.space, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: SampleTime(time)).first
        )
        guard case let .picture(picture) = item.content, case let .displayList(list) = picture.source else {
            Issue.record("the title draws a group")
            return DisplayList(size: Size(width: 0, height: 0), background: Color(written: "#00000000"), seed: 0, items: [])
        }

        return list
    }

    private func glyphs(of item: DisplayItem) -> GlyphsItem? {
        guard case let .glyphs(glyphs) = item.content else { return nil }

        return glyphs
    }

    private func layer(of item: DisplayItem) -> GlyphLayer? {
        glyphs(of: item)?.layer
    }

    private func highlight(of item: DisplayItem) -> DrawnHighlight? {
        glyphs(of: item)?.runs.first?.highlight
    }

    // `clip` with its animation replaced: by word at `stagger`, or as a whole without one.
    private func animated(
        _ clip: ResolvedClip,
        entrance: AnimationSpan?,
        loop: AnimationSpan? = nil,
        stagger: Double?
    ) -> ResolvedClip {
        ResolvedClip(
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
            animation: ResolvedAnimation(
                entrance: entrance,
                loop: loop,
                exit: nil,
                units: stagger.map { UnitStagger(by: .word, stagger: $0) }
            )
        )
    }

    private func title(of clip: ResolvedClip) throws -> ResolvedText {
        guard case let .title(text) = clip.content else {
            Issue.record("the clip is a title")
            return ResolvedText(size: Size(width: 0, height: 0), background: nil, runs: [])
        }

        return text
    }

    private func resolvedClip(_ clip: String) throws -> ResolvedClip {
        let plan = try Fixture.documentPlanner.plan(try Fixture.json(document(clip)))

        return try #require(try ResolvedSequence(plan: plan, hashes: FileHashTable()).clips.first)
    }

    private func document(_ clip: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [1920, 1080] },
              "theme": { "styles": { "caption": { "size": 40, "color": "#000000", "stroke": { "width": 4, "color": "#000000" } } } },
              "storyline": [ { "media": "/abs/screen.mp4" } ],
              "clips": [ \#(clip.dropLast(1)), "animation": { "preset": "frames/fade", "by": "word" }, "at": [0, 2] } ] }
            """#
    }
}
