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

    private let frame = ClipSpace(frame: Rectangle(x: 0, y: 0, width: 200, height: 200))
    private let white = Color(written: "#FFFFFF")
    // A parent that doubles its space and moves it by (10, 0).
    private let parent = ClipSpace(
        frame: Rectangle(x: 0, y: 0, width: 200, height: 200),
        transform: AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 10, ty: 0)
    )
    private let media = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/media.mp4", sha256: String(repeating: "a", count: 64))),
        frameTimes: [0]
    )
    // Scale 2 throughout a two second entrance.
    private let doubling = ResolvedAnimation(
        entrance: AnimationSpan(length: 2, span: Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.scale: 2]),
            SpanKey(t: 1, values: [.scale: 2])
        ])),
        loop: nil,
        exit: nil,
        units: nil
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a title's entrance scales it about its bottom anchor, fades it and wipes it from the bottom of its box")
    func animatesTitleAboutBottomAnchor() {
        // Given
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .bottom, keys: [
            SpanKey(t: 0, values: [.scale: 0.5, .opacity: 0, .reveal: 0]),
            SpanKey(t: 1, values: [.scale: 1, .opacity: 1, .reveal: 1])
        ]))
        let text = ResolvedText(size: Size(width: 100, height: 40), background: nil, runs: [])
        let clip = title(text, animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil, units: nil), opacity: 0.8)

        // When
        let items = sut.items(of: clip, in: frame, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: 0.5)

        // Then
        // Halfway the scale is 0.75 about the bottom centre (50, 40) of the box, which stays at (100, 200), so the top
        // left goes to (62.5, 170). Half the box shows from its bottom.
        #expect(items == [DisplayItem(
            transform: AffineTransform(a: 0.75, b: 0, c: 0, d: 0.75, tx: 62.5, ty: 170),
            opacity: 0.4,
            reveal: Rectangle(x: 0, y: 20, width: 100, height: 20),
            content: .glyphs(GlyphsItem(text: text, factor: 1, at: 0.5))
        )])
    }

    @Test("a media clip's reveal wipes across its box and its shadow, and its border inside the box adds nothing")
    func revealsMediaClipWithShadow() throws {
        // Given
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .left, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ]))
        let appearance = ResolvedMediaAppearance(
            conform: .fit,
            radius: 0,
            border: .border(MediaBorder(width: 4, color: white)),
            shadow: .shadow(DropShadow(radius: 2, offset: Point(x: 4, y: 6), color: white))
        )
        let clip = ResolvedClip(
            place: "clips[0]",
            id: nil,
            content: .media(ResolvedMediaClip(media: .pinned(media), timing: nil, filter: .off, appearance: appearance)),
            start: 0,
            end: 4,
            lane: 1,
            storyline: nil,
            parent: nil,
            box: box(size: Size(width: 80, height: 40), at: Point(x: 100, y: 100), anchor: Point(x: 40, y: 20)),
            crop: nil,
            mask: nil,
            trackMatte: nil,
            track: nil,
            opacity: [Keyframe(at: 0, value: 1)],
            scale: [Keyframe(at: 0, value: .identity)],
            rotation: [Keyframe(at: 0, value: 0)],
            blend: "normal",
            animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil, units: nil)
        )

        // When
        let items = sut.items(of: clip, in: frame, picture: .media(MediaFrame(media: media, index: 0)), trackMatte: nil, compositing: .encoded, seed: 0, at: 0.5)

        // Then
        // The shadow is the 80 x 40 box moved by (4, 6) and grown by three times its radius, (-2, 0) to (90, 52), and
        // with the box it spans 92 x 52 from (-2, 0). Halfway, the left half of that shows.
        let item = try #require(items.first)
        #expect(item.reveal == Rectangle(x: -2, y: 0, width: 46, height: 52))
    }

    @Test("a title's keyframed scale and rotation act about its anchor point, and its background fills its whole box")
    func transformsTitleAboutAnchor() throws {
        // Given
        let text = ResolvedText(
            size: Size(width: 100, height: 40),
            background: TextBackground(color: white, padding: Size(width: 8, height: 4), radius: 6),
            runs: []
        )
        let clip = title(text, animation: .none, opacity: 1, scale: 2, rotation: 90)

        // When
        let items = sut.items(of: clip, in: frame, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: 1)

        // Then
        // Doubled and turned a quarter clockwise about (50, 40), which stays at (100, 200) once the box sits at
        // (50, 160): the box's top left goes to (180, 100), and its x axis points down.
        let item = try #require(items.first)
        let expected = AffineTransform(a: 0, b: 2, c: -2, d: 0, tx: 180, ty: 100)
        #expect(items.count == 1)
        #expect(isClose(item.transform, expected))
        #expect(item.content == .glyphs(GlyphsItem(
            size: Size(width: 100, height: 40),
            runs: [],
            background: GlyphBackground(rectangle: Rectangle(x: 0, y: 0, width: 100, height: 40), radius: 6, color: white)
        )))
    }

    @Test("a box clip under a scaled and turned parent keeps its size, its anchor point carried and its turn added")
    func keepsBoxSizeUnderParent() throws {
        // Given
        // P doubles, turns a quarter clockwise and moves by (300, 0), so the anchor point (100, 200) lands at
        // (-100, 200). The box keeps its 100 x 40 size and turns a quarter about its bottom centre (50, 40).
        let text = ResolvedText(size: Size(width: 100, height: 40), background: nil, runs: [])
        let clip = title(text, animation: .none, opacity: 1)
        let transform = AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0)
            .concatenating(AffineTransform(rotation: 90, about: Point(x: 0, y: 0)))
            .concatenating(AffineTransform(translation: Point(x: 300, y: 0)))
        let space = ClipSpace(frame: Rectangle(x: 0, y: 0, width: 200, height: 200), transform: transform)

        // When
        let items = sut.items(of: clip, in: space, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: 1)

        // Then
        let item = try #require(items.first)
        #expect(isClose(item.transform, AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: -60, ty: 150)))
    }

    @Test(
        "a mask's geometry is in the space its clip gives its children and is carried with it under a parent",
        arguments: ["title", "media clip with a crop", "box shape", "area shape", "adjustment"]
    )
    func carriesMaskInClipSpace(kind: String) throws {
        // Given
        // Under the parent, the anchor point of a clip with a box of its own is carried and its box keeps its size. A
        // title's 100 x 40 box anchored at (50, 40) on (100, 200) lands with its top left at (160, 360). The media
        // clip's 80 x 40 box shows the crop (100, 50, 200, 100) of its media at 0.4 of its size, its top left at
        // (70, 60). The rect's 40 x 20 box anchored at its centre on (60, 30) has its top left at (110, 50). The area
        // shape turns a quarter about the centre (60, 30) of its area, and the adjustment doubles about the centre of
        // its mask's bounds, before the parent's map.
        let clip: ResolvedClip
        let geometry: PathGeometry
        let expected: [(Point, Point)]
        switch kind {
        case "title":
            geometry = .rect(Rectangle(x: 0, y: 0, width: 100, height: 40), radius: 0)
            clip = masked(
                .title(text()),
                mask: geometry,
                box: box(size: Size(width: 100, height: 40), at: Point(x: 50, y: 160), anchor: Point(x: 50, y: 40))
            )
            expected = [(Point(x: 0, y: 0), Point(x: 160, y: 360)), (Point(x: 100, y: 40), Point(x: 260, y: 400))]

        case "media clip with a crop":
            geometry = .ellipse(Rectangle(x: 100, y: 50, width: 200, height: 100))
            clip = masked(
                .media(ResolvedMediaClip(
                    media: .pinned(media),
                    timing: nil,
                    filter: .off,
                    appearance: ResolvedMediaAppearance(conform: .fit, radius: .off, border: .off, shadow: .off)
                )),
                mask: geometry,
                box: box(size: Size(width: 80, height: 40), at: Point(x: 10, y: 20), anchor: Point(x: 40, y: 20)),
                crop: Rectangle(x: 100, y: 50, width: 200, height: 100)
            )
            expected = [(Point(x: 100, y: 50), Point(x: 70, y: 60)), (Point(x: 300, y: 150), Point(x: 150, y: 100))]

        case "box shape":
            geometry = .rect(Rectangle(x: 0, y: 0, width: 40, height: 20), radius: 0)
            clip = masked(
                .shape(ResolvedShape(
                    kind: .rect,
                    geometry: .box(
                        width: [Keyframe(at: 0, value: 40)],
                        height: [Keyframe(at: 0, value: 20)],
                        outset: 0
                    ),
                    radius: 0,
                    trim: [Keyframe(at: 0, value: .whole)],
                    fill: .fill(white),
                    stroke: .off,
                    shadow: .off
                )),
                mask: geometry,
                box: box(size: Size(width: 40, height: 20), at: Point(x: 40, y: 20), anchor: Point(x: 20, y: 10))
            )
            expected = [(Point(x: 0, y: 0), Point(x: 110, y: 50)), (Point(x: 40, y: 20), Point(x: 150, y: 70))]

        case "area shape":
            geometry = .rect(Rectangle(x: 40, y: 20, width: 40, height: 20), radius: 0)
            let area = Rectangle(x: 40, y: 20, width: 40, height: 20)
            let shape = ResolvedShape(area: [Keyframe(at: 0, value: area)], fill: white)
            clip = masked(.shape(shape), mask: geometry, rotation: 90)
            expected = [(Point(x: 60, y: 30), Point(x: 130, y: 60)), (Point(x: 40, y: 20), Point(x: 150, y: 20))]

        default:
            geometry = .rect(Rectangle(x: 40, y: 20, width: 40, height: 20), radius: 0)
            clip = masked(.adjustment(.filter([.blur(radius: 2)])), mask: geometry, animation: doubling)
            expected = [(Point(x: 60, y: 30), Point(x: 130, y: 60)), (Point(x: 40, y: 20), Point(x: 50, y: 20))]
        }

        // When
        let items = sut.items(of: clip, in: parent, picture: .media(MediaFrame(media: media, index: 0)), trackMatte: nil, compositing: .encoded, seed: 0, at: 1)

        // Then
        let item = try #require(items.first)
        let mask = try #require(item.mask.first)
        #expect(item.mask.count == 1)
        #expect(mask.geometry == geometry)
        for (point, output) in expected {
            expect(mask.transform.apply(to: point), output)
        }
    }

    @Test(
        "a mask's feather grows with its clip's own and its animation's scale and not with its parent's",
        arguments: [("title", 6.0, 6.0), ("area shape", 6.0, 12.0), ("adjustment", 2.0, 4.0)]
    )
    func scalesFeatherByOwnScaleOnly(
        kind: String,
        factor: Double,
        carried: Double
    ) throws {
        // Given
        // The parent doubles its space, the clip is at scale 3 where it takes one, and its entrance doubles it.
        let area = Rectangle(x: 0, y: 0, width: 40, height: 20)
        let geometry = PathGeometry.ellipse(area)
        let content: ResolvedClipContent = switch kind {
        case "title":
            .title(text())

        case "area shape":
            .shape(ResolvedShape(area: [Keyframe(at: 0, value: area)], fill: white))

        default:
            .adjustment(.filter([.blur(radius: 2)]))
        }
        let isAdjustment = kind == "adjustment"
        let clip = masked(
            content,
            mask: geometry,
            feather: 1.5,
            box: kind == "title" ? box(size: text().size, at: Point(x: 0, y: 0), anchor: Point(x: 0, y: 0)) : nil,
            scale: isAdjustment ? nil : 3,
            animation: doubling
        )

        // When
        let items = sut.items(of: clip, in: parent, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: 1)

        // Then
        // The mask is carried with what it cuts, at the parent's scale for a shape and an adjustment, whose geometry is
        // in the parent's space, and at its own for a title, whose box keeps its size. Its feather never takes the
        // parent's.
        let mask = try #require(items.first?.mask.first)
        let scale = (mask.transform.a * mask.transform.a + mask.transform.b * mask.transform.b).squareRoot()
        #expect(abs(mask.feather - 1.5 * factor) < 1e-9)
        #expect(abs(scale - carried) < 1e-9)
    }

    @Test("between two keyframes a mask interpolates its geometry, its corner radius and its feather")
    func interpolatesKeyframedMask() throws {
        // Given
        let mask = [ResolvedMask(
            samples: [
                (at: 0, geometry: .rect(Rectangle(x: 0, y: 0, width: 20, height: 10), radius: 2), feather: 2),
                (at: 2, geometry: .rect(Rectangle(x: 20, y: 10, width: 40, height: 30), radius: 6), feather: 6)
            ],
            isInverted: true,
            mode: .subtract
        )]
        let clip = masked(
            .title(text()),
            mask: mask,
            box: box(size: Size(width: 100, height: 40), at: Point(x: 50, y: 160), anchor: Point(x: 50, y: 40))
        )

        // When
        let items = sut.items(of: clip, in: frame, picture: nil, trackMatte: nil, compositing: .encoded, seed: 0, at: 1)

        // Then
        let item = try #require(items.first)
        #expect(item.mask == [ItemMask(
            geometry: .rect(Rectangle(x: 10, y: 5, width: 30, height: 20), radius: 4),
            transform: item.transform,
            feather: 4,
            isInverted: true,
            mode: .subtract
        )])
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
            parent: nil,
            box: ResolvedBox(
                size: text.size,
                position: [Keyframe(at: 0, value: Point(x: 100, y: 200))],
                anchor: Point(x: 50, y: 40)
            ),
            crop: nil,
            mask: nil,
            trackMatte: nil,
            track: nil,
            opacity: [Keyframe(at: 0, value: opacity)],
            scale: [Keyframe(at: 0, value: Scale(scale))],
            rotation: [Keyframe(at: 0, value: rotation)],
            blend: "normal",
            animation: animation
        )
    }

    // A clip of `content` visible from 0 to 4 with one mask of `geometry`.
    private func masked(
        _ content: ResolvedClipContent,
        mask geometry: PathGeometry,
        feather: Double = 0,
        box: ResolvedBox? = nil,
        crop: Rectangle? = nil,
        scale: Double? = nil,
        rotation: Double? = nil,
        animation: ResolvedAnimation = .none
    ) -> ResolvedClip {
        masked(
            content,
            mask: [ResolvedMask(geometry: geometry, feather: feather, isInverted: false, mode: .add)],
            box: box,
            crop: crop,
            scale: scale,
            rotation: rotation,
            animation: animation
        )
    }

    private func masked(
        _ content: ResolvedClipContent,
        mask: [ResolvedMask],
        box: ResolvedBox? = nil,
        crop: Rectangle? = nil,
        scale: Double? = nil,
        rotation: Double? = nil,
        animation: ResolvedAnimation = .none
    ) -> ResolvedClip {
        let isAdjustment = if case .adjustment = content { true } else { false }

        return ResolvedClip(
            place: "clips[0]",
            id: nil,
            content: content,
            start: 0,
            end: 4,
            lane: 1,
            storyline: nil,
            parent: nil,
            box: box,
            crop: crop.map { .keyframes([Keyframe(at: 0, value: Crop($0))]) },
            mask: mask,
            trackMatte: nil,
            track: nil,
            opacity: [Keyframe(at: 0, value: 1)],
            scale: isAdjustment ? nil : [Keyframe(at: 0, value: Scale(scale ?? 1))],
            rotation: isAdjustment ? nil : [Keyframe(at: 0, value: rotation ?? 0)],
            blend: "normal",
            animation: animation
        )
    }

    // A box whose top left is at `topLeft`.
    private func box(
        size: Size,
        at topLeft: Point,
        anchor: Point
    ) -> ResolvedBox {
        ResolvedBox(
            size: size,
            position: [Keyframe(at: 0, value: Point(x: topLeft.x + anchor.x, y: topLeft.y + anchor.y))],
            anchor: anchor
        )
    }

    private func text() -> ResolvedText {
        ResolvedText(size: Size(width: 100, height: 40), background: nil, runs: [])
    }

    private func expect(
        _ point: Point,
        _ expected: Point,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(point.x - expected.x) < 1e-9 && abs(point.y - expected.y) < 1e-9,
            "\(point) is not \(expected)",
            sourceLocation: sourceLocation
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
