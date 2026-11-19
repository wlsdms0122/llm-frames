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
        let items = sut.items(of: byWord, in: space, picture: nil, trackMatte: nil, seed: 7, at: 1)
        let single = try #require(sut.items(of: whole, in: space, picture: nil, trackMatte: nil, seed: 7, at: 1).first)

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
        #expect(list.items.map(\.transform) == Array(repeating: single.transform, count: 9))
        #expect(list.items.map { layer(of: $0) } == [GlyphLayer?.none] + GlyphLayer.allCases.flatMap { [$0, $0] })
        #expect(list.items.map { self.glyphs(of: $0)?.runs.flatMap(\.glyphs).count ?? -1 } == [0] + Array(repeating: 2, count: 8))
        #expect(self.glyphs(of: list.items[7])?.runs.first?.glyphs == Array(glyphs.runs[0].glyphs[0..<2]))
        #expect(self.glyphs(of: list.items[8])?.runs.first?.glyphs == Array(glyphs.runs[0].glyphs[3..<5]))
    }

    @Test("each unit's reveal wipes what it draws, its box and its stroke, on its own schedule, and the background shows whole")
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
        // Each unit's box grows by 2, half its stroke.
        let first = text.unitBox(of: 0, at: 0.25)
        let second = text.unitBox(of: 1, at: 0.25)
        #expect(list.items[0].reveal == nil)
        #expect(list.items[1].reveal == Rectangle(
            x: first.x - 2,
            y: first.y - 2,
            width: (first.width + 4) / 2,
            height: first.height + 4
        ))
        #expect(list.items[2].reveal == Rectangle(x: second.x - 2, y: second.y - 2, width: 0, height: second.height + 4))
    }

    @Test("a unit fully revealed is not cut, and one entering wipes its box grown by its stroke and its part of the highlight")
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
        // "ab" has entered, and "cd" is half way.
        let second = text.unitBox(of: 1, at: 0.75)
        let carried = try #require(highlight(of: list.items[2]))
        let band = try #require(carried.bands?.first)
        let piece = try #require(carried.rects.first)
        let stroked = Rectangle(x: second.x - 2, y: second.y - 2, width: second.width + 4, height: second.height + 4)
        let drawn = stroked.union(Rectangle(
            x: band.lowerBound,
            y: piece.y,
            width: band.upperBound - band.lowerBound,
            height: piece.height
        ))
        #expect(list.items[1].reveal == nil)
        #expect(list.items[2].reveal == Rectangle(x: drawn.x, y: drawn.y, width: drawn.width / 2, height: drawn.height))
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
            seed: 0,
            at: 0.25
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
            x: text.unitBox(of: 0, at: 0.25).width / 2,
            y: 0
        )))
        #expect(list.items[2].transform.apply(to: origin) == title.transform.apply(to: Point(
            x: text.unitBox(of: 1, at: 0.25).width,
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
            seed: 0,
            at: 1
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
            sut.items(of: animation(nil), in: space, picture: nil, trackMatte: nil, seed: 0, at: 1).first
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
            seed: 0,
            items: sut.items(of: animated(clip, entrance: fade, stagger: 0.1), in: space, picture: nil, trackMatte: nil, seed: 0, at: 0.2)
        )

        // When
        let read = try DisplayListReader().read(DisplayListWriter().write(list))

        // Then
        #expect(read == list)
    }

    @Test("a title's units cover only their boxes, and its background only where it has one")
    func flattensGroup() throws {
        // Given
        let plain = try resolvedClip(#"{ "title": "ab cd", "style": "caption", "position": [400, 225] }"#)
        let boxed = try resolvedClip(#"""
            { "title": "ab cd", "style": "caption", "position": [400, 225],
              "paragraph": { "background": { "color": "#FFFFFF" } } }
            """#)
        let flattener = DisplayListFlattener()
        let flattened = { (clip: ResolvedClip) in
            flattener.items(of: DisplayList(
                size: Size(width: 1920, height: 1080),
                background: Color(written: "#00000000"),
                seed: 0,
                items: self.sut.items(
                    of: self.animated(clip, entrance: self.fade, stagger: 0.1),
                    in: self.space,
                    picture: nil,
                    trackMatte: nil,
                    seed: 0,
                    at: 1
                )
            ))
        }
        // The title's box, 90 wide, is centred on (400, 225): "cd" starts 50 from its left edge, and the gap between
        // the words, 42 to 48 with their strokes, belongs to no unit.
        let gap = Point(x: 400, y: 225)
        let word = Point(x: 400 + 15, y: 225)

        // When
        let plainItems = flattened(plain)
        let boxedItems = flattened(boxed)

        // Then
        #expect(plainItems.count == 8)
        #expect(plainItems.filter { $0.coverage.contains(gap) }.isEmpty)
        #expect(plainItems.filter { $0.coverage.contains(word) }.count == 4)
        #expect(boxedItems.count == 9)
        #expect(boxedItems.filter { $0.coverage.contains(gap) }.count == 1)
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
        at time: Double
    ) throws -> DisplayList {
        let item = try #require(sut.items(of: clip, in: space, picture: nil, trackMatte: nil, seed: 0, at: time).first)
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
