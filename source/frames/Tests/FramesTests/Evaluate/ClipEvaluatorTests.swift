//
//  ClipEvaluatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ClipEvaluator Tests")
struct ClipEvaluatorTests {
    // MARK: - Property
    private let sut = ClipEvaluator()

    private let frame = ClipSpace(room: Rectangle(x: 0, y: 0, width: 200, height: 200))
    private let white = Color(written: "#FFFFFF")

    // MARK: - Initializer
    // MARK: - Test
    @Test("a title's entrance scales it about its bottom anchor, fades it and wipes it from the bottom of its box")
    func animatesTitleAboutBottomAnchor() {
        // Given
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .bottom, keys: [
            SpanKey(t: 0, values: [.scale: 0.5, .opacity: 0, .reveal: 0]),
            SpanKey(t: 1, values: [.scale: 1, .opacity: 1, .reveal: 1])
        ]))
        let text = ResolvedText(size: Size(width: 100, height: 40), lineCount: 1, background: nil, stroke: nil, runs: [])
        let clip = title(text, animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil), opacity: 0.8)

        // When
        let items = sut.items(of: clip, in: frame, picture: nil, at: 0.5)

        // Then
        // Halfway the scale is 0.75 about the bottom centre (50, 40) of the box, which stays at (100, 200), so the top
        // left goes to (62.5, 170). Half the box shows from its bottom.
        #expect(items == [DisplayItem(
            transform: AffineTransform(a: 0.75, b: 0, c: 0, d: 0.75, tx: 62.5, ty: 170),
            opacity: 0.4,
            reveal: Rectangle(x: 0, y: 20, width: 100, height: 20),
            content: .glyphs(GlyphsItem(text: text))
        )])
    }

    @Test("a title's keyframed scale and rotation act about its anchor point, and its background fills its whole box")
    func transformsTitleAboutAnchor() throws {
        // Given
        let text = ResolvedText(
            size: Size(width: 100, height: 40),
            lineCount: 1,
            background: TextBackground(color: white, padding: Size(width: 8, height: 4), radius: 6),
            stroke: nil,
            runs: []
        )
        let clip = title(text, animation: .none, opacity: 1, scale: 2, rotation: 90)

        // When
        let items = sut.items(of: clip, in: frame, picture: nil, at: 1)

        // Then
        // Doubled and turned a quarter clockwise about (50, 40), which stays at (100, 200) once the box sits at
        // (50, 160): the box's top left goes to (180, 100), and its x axis points down.
        let item = try #require(items.first)
        let expected = AffineTransform(a: 0, b: 2, c: -2, d: 0, tx: 180, ty: 100)
        #expect(items.count == 1)
        #expect(isClose(item.transform, expected))
        #expect(item.content == .glyphs(GlyphsItem(
            runs: [],
            stroke: nil,
            background: GlyphBackground(rectangle: Rectangle(x: 0, y: 0, width: 100, height: 40), radius: 6, color: white)
        )))
    }

    // MARK: - Private
    // A title whose 100 x 40 box sits at (50, 160), anchored at its bottom centre, visible from 0 to 4.
    private func title(
        _ text: ResolvedText,
        animation: ResolvedAnimation,
        opacity: Double,
        scale: Double = 1,
        rotation: Double = 0
    ) -> ResolvedClip {
        ResolvedClip(
            place: "clips[0]",
            id: nil,
            content: .title(text),
            start: 0,
            end: 4,
            lane: 1,
            storyline: nil,
            isParented: false,
            area: nil,
            box: ResolvedBox(
                size: text.size,
                position: [Keyframe(at: 0, value: Point(x: 50, y: 160))],
                anchor: Point(x: 50, y: 40)
            ),
            crop: nil,
            track: nil,
            label: nil,
            opacity: [Keyframe(at: 0, value: opacity)],
            scale: [Keyframe(at: 0, value: scale)],
            rotation: [Keyframe(at: 0, value: rotation)],
            blend: "normal",
            animation: animation
        )
    }

    private func isClose(
        _ transform: AffineTransform,
        _ other: AffineTransform
    ) -> Bool {
        [
            transform.a - other.a,
            transform.b - other.b,
            transform.c - other.c,
            transform.d - other.d,
            transform.tx - other.tx,
            transform.ty - other.ty
        ]
        .allSatisfy { abs($0) < 1e-9 }
    }
}
