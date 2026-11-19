//
//  ParentEvaluatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

// A 200 x 100 frame. The storyline plays "shot", a 400 x 200 video, from 0 to 2, then "next", a solid brought in from
// 1.5 to 2.5 by a push from the right, to 4.
@Suite("ParentEvaluator Tests")
struct ParentEvaluatorTests {
    // MARK: - Property
    private let size = Size(width: 200, height: 100)
    private let whole = Rectangle(x: 0, y: 0, width: 400, height: 200)
    // From the whole picture at 0 to its middle 200 x 100 at 1.
    private let zoom = [
        Keyframe(at: 0, value: Crop(Rectangle(x: 0, y: 0, width: 400, height: 200))),
        Keyframe(at: 1, value: Crop(Rectangle(x: 100, y: 50, width: 200, height: 100)))
    ]
    private let media = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/shot.mp4", sha256: String(repeating: "a", count: 64))),
        frameTimes: (0..<20).map { Double($0) / 4 }
    )
    private let red = Color(written: "#FF0000")
    private let text = ResolvedText(
        size: Size(width: 100, height: 40),
        background: nil,
        runs: []
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a storyline parent maps its media pixels through its conformed crop onto the frame",
        arguments: [
            (0.0, AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0)),
            (1.5, AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: -100, ty: -50))
        ]
    )
    func mapsStorylineCrop(
        time: Double,
        transform: AffineTransform
    ) {
        // Given
        let child = fill(parent: "shot")
        let resolved = sequence(clips: [child], crop: zoom)
        let sut = ParentEvaluator(sequence: resolved)

        // When
        let space = sut.space(of: child, at: time)

        // Then
        #expect(isClose(space.transform, transform))
        #expect(space.clock == resolved.storyline[0].clock)
    }

    @Test(
        "a solid parent is the frame carried by its transition's move, held at the edge of its drawn range before it",
        arguments: [
            (3.0, 0.0),
            (1.75, 150.0),
            (1.0, 200.0)
        ]
    )
    func movesWithSolidTransition(
        time: Double,
        x: Double
    ) {
        // Given
        let child = fill(parent: "next")
        let sut = ParentEvaluator(sequence: sequence(clips: [child]))

        // When
        let space = sut.space(of: child, at: time)

        // Then
        #expect(isClose(space.transform, AffineTransform(translation: Point(x: x, y: 0))))
    }

    @Test("a media clip parent maps its media pixels through its crop into its box")
    func mapsMediaClipCrop() {
        // Given
        // The whole 400 x 200 picture in an 80 x 40 box whose top left is at (10, 20).
        let parent = clip(
            id: "card",
            content: .media(ResolvedMediaClip(
                media: .pinned(media),
                timing: nil,
                filter: .off,
                appearance: ResolvedMediaAppearance(conform: .fit, radius: .off, border: .off, shadow: .off)
            )),
            box: ResolvedBox(
                size: Size(width: 80, height: 40),
                position: [Keyframe(at: 0, value: Point(x: 10, y: 20))],
                anchor: Point(x: 40, y: 20)
            ),
            crop: [Keyframe(at: 0, value: Crop(whole))]
        )
        let child = fill(parent: "card")
        let sut = ParentEvaluator(sequence: sequence(clips: [parent, child]))

        // When
        let space = sut.space(of: child, at: 1)

        // Then
        #expect(isClose(space.transform, AffineTransform(a: 0.2, b: 0, c: 0, d: 0.2, tx: 10, ty: 20)))
    }

    @Test("a title parent gives its item's transform, its scale about its anchor point")
    func mapsTitleBox() {
        // Given
        // A 100 x 40 box at (50, 160), doubled about its bottom centre, which stays at (100, 200).
        let parent = title(id: "label", parent: nil, position: Point(x: 50, y: 160), scale: 2)
        let child = fill(parent: "label")
        let sut = ParentEvaluator(sequence: sequence(clips: [parent, child]))

        // When
        let space = sut.space(of: child, at: 1)

        // Then
        #expect(isClose(space.transform, AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 120)))
    }

    @Test(
        "a shape parent with an area or an adjustment parent with a mask gives the space they are written in, carried by its presentation",
        arguments: [
            ResolvedClipContent.shape(ResolvedShape(
                area: [Keyframe(at: 0, value: Rectangle(x: 0, y: 0, width: 40, height: 20))],
                fill: Color(written: "#FF0000")
            )),
            .adjustment(.filter([.blur(radius: 3)]))
        ]
    )
    func mapsAreaParent(content: ResolvedClipContent) {
        // Given
        let isShape = if case .shape = content { true } else { false }
        let mask = ResolvedMask(
            geometry: .rect(Rectangle(x: 0, y: 0, width: 40, height: 20), radius: 0),
            feather: 0,
            isInverted: false,
            mode: .add
        )
        let parent = clip(
            id: "bar",
            content: content,
            parent: "shot",
            mask: isShape ? nil : [Keyframe(at: 0, value: [mask])]
        )
        let child = fill(parent: "bar")
        let sut = ParentEvaluator(sequence: sequence(clips: [parent, child]))

        // When
        let space = sut.space(of: child, at: 1)

        // Then
        #expect(isClose(space.transform, AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0)))
    }

    @Test("a three-deep chain composes each parent's map down to the output")
    func composesChain() {
        // Given
        // The title keeps its size under the half-size picture: its bottom centre (100, 200) in the picture lands at
        // (50, 100), so its box's top left moves from (50, 160) to (0, 60).
        let bar = clip(
            id: "bar",
            content: .shape(ResolvedShape(
                area: [Keyframe(at: 0, value: Rectangle(x: 0, y: 0, width: 40, height: 20))],
                fill: red
            )),
            parent: "shot"
        )
        let label = title(id: "label", parent: "bar", position: Point(x: 50, y: 160), scale: 1)
        let child = fill(parent: "label")
        let sut = ParentEvaluator(sequence: sequence(clips: [bar, label, child]))

        // When
        let space = sut.space(of: child, at: 1)

        // Then
        #expect(isClose(space.transform, AffineTransform(translation: Point(x: 0, y: 60))))
    }

    @Test(
        "a title parented to a shape that tracks a media clip parent's media follows the motion at the media time it shows",
        arguments: [
            (0.0, Point(x: -30, y: -12)),
            (0.5, Point(x: -26, y: -12))
        ]
    )
    func followsShapeTrackedInMediaClip(
        time: Double,
        position: Point
    ) throws {
        // Given
        // The card shows media time 2 at sequence time 0, its whole 400 x 200 picture in an 80 x 40 box at (10, 20).
        // At media time 2.5 the target has moved 20 right, so the title's anchor point (50, 40) in the card's media
        // moves 4 right in output pixels.
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 2, frames: [
            TrackedFrame(time: 2, rectangle: target),
            TrackedFrame(time: 2.5, rectangle: Rectangle(x: 20, y: 0, width: 10, height: 10))
        ])
        let card = clip(
            id: "card",
            content: .media(ResolvedMediaClip(
                media: .pinned(media),
                timing: .played(PlayedRange(map: TimeMap(origin: 0, in: 2, speed: 1), out: 4.75, loop: false)),
                filter: .off,
                appearance: ResolvedMediaAppearance(conform: .fit, radius: .off, border: .off, shadow: .off)
            )),
            box: ResolvedBox(
                size: Size(width: 80, height: 40),
                position: [Keyframe(at: 0, value: Point(x: 10, y: 20))],
                anchor: Point(x: 40, y: 20)
            ),
            crop: [Keyframe(at: 0, value: Crop(whole))]
        )
        let box = clip(
            id: "box",
            content: .shape(ResolvedShape(
                area: [Keyframe(at: 0, value: target)],
                fill: nil,
                stroke: PathStroke(width: 2, color: red, join: .round, cap: .butt, start: .none, end: .none)
            )),
            parent: "card",
            track: track
        )
        let label = title(id: "label", parent: "box", position: Point(x: 0, y: 0), scale: 1)
        let parents = ParentEvaluator(sequence: sequence(clips: [card, box, label]))
        let sut = ClipEvaluator()

        // When
        let items = sut.items(of: label, in: parents.space(of: label, at: time), picture: nil, trackMatte: nil, seed: 0, at: time)

        // Then
        let item = try #require(items.first)
        #expect(isClose(item.transform, AffineTransform(translation: position)))
    }

    @Test("past its media clip parent's window a tracked shape follows the frame the parent's clock gives, on the parent held at its edge")
    func followsMediaClipParentPastItsWindow() throws {
        // Given
        // The card, visible over [0, 1), shows media time 2 + t at t, its whole 400 x 200 picture in an 80 x 40 box
        // whose top left moves from (10, 20) at 0 to (50, 20) at 2, so it holds at (30, 20). At 1.5 its clock gives
        // media time 3.5, where the target has moved 30 right, 6 in output pixels.
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 2, frames: [
            TrackedFrame(time: 2, rectangle: target),
            TrackedFrame(time: 3, rectangle: Rectangle(x: 20, y: 0, width: 10, height: 10)),
            TrackedFrame(time: 3.5, rectangle: Rectangle(x: 30, y: 0, width: 10, height: 10))
        ])
        let card = clip(
            id: "card",
            content: .media(ResolvedMediaClip(
                media: .pinned(media),
                timing: .played(PlayedRange(map: TimeMap(origin: 0, in: 2, speed: 1), out: 4.75, loop: false)),
                filter: .off,
                appearance: ResolvedMediaAppearance(conform: .fit, radius: .off, border: .off, shadow: .off)
            )),
            end: 1,
            box: ResolvedBox(
                size: Size(width: 80, height: 40),
                position: [Keyframe(at: 0, value: Point(x: 10, y: 20)), Keyframe(at: 2, value: Point(x: 50, y: 20))],
                anchor: Point(x: 40, y: 20)
            ),
            crop: [Keyframe(at: 0, value: Crop(whole))]
        )
        let box = clip(
            id: "box",
            content: .shape(ResolvedShape(
                area: [Keyframe(at: 0, value: target)],
                fill: nil,
                stroke: PathStroke(width: 2, color: red, join: .round, cap: .butt, start: .none, end: .none)
            )),
            parent: "card",
            track: track
        )
        let sut = ParentEvaluator(sequence: sequence(clips: [card, box]))

        // When
        let space = sut.space(of: box, at: 1.5)

        // Then
        let corner = space.tracked(by: box.parentTrack, at: 1.5).transform.apply(to: Point(x: 0, y: 0))
        // The hold is a time resolution before the edge, 2e-5 px short of (30, 20) on this move.
        #expect(space.clock == card.clock)
        #expect(abs(corner.x - 36) < 1e-4)
        #expect(abs(corner.y - 20) < 1e-4)
    }

    @Test(
        "a title parented to a shape that tracks its storyline parent's media follows the tracked motion on each frame",
        arguments: [
            (0.0, Point(x: -25, y: -20)),
            (0.5, Point(x: -15, y: -20)),
            (1.0, Point(x: 7.5, y: -2.5))
        ]
    )
    func followsTrackedShape(
        time: Double,
        position: Point
    ) throws {
        // Given
        // The target moves 20 right at 0.5, and at 1 its centre moves from (5, 5) to (25, 5) and it doubles. The
        // title's anchor point (50, 40) in the picture is carried by that motion and then at half size.
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 0, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 0.5, rectangle: Rectangle(x: 20, y: 0, width: 10, height: 10)),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 15, y: -5, width: 20, height: 20))
        ])
        let box = clip(
            id: "box",
            content: .shape(ResolvedShape(
                area: [Keyframe(at: 0, value: target)],
                fill: nil,
                stroke: PathStroke(width: 2, color: red, join: .round, cap: .butt, start: .none, end: .none)
            )),
            parent: "shot",
            track: track
        )
        let label = title(id: "label", parent: "box", position: Point(x: 0, y: 0), scale: 1)
        let parents = ParentEvaluator(sequence: sequence(clips: [box, label]))
        let sut = ClipEvaluator()

        // When
        let items = sut.items(of: label, in: parents.space(of: label, at: time), picture: nil, trackMatte: nil, seed: 0, at: time)

        // Then
        let item = try #require(items.first)
        #expect(isClose(item.transform, AffineTransform(translation: position)))
    }

    @Test(
        "a parent is evaluated whether visible or not, holding the values at its window's edges outside it",
        arguments: [
            (0.0, 0.0),
            (1.25, 50.0),
            (3.0, 100.0)
        ]
    )
    func holdsParentOutsideWindow(
        time: Double,
        x: Double
    ) {
        // Given
        // Visible from 1 to 2, its box's top left moving from (0, 0) at 1 to (100, 0) at 1.5.
        let parent = clip(
            id: "label",
            content: .title(text),
            start: 1,
            end: 2,
            box: ResolvedBox(
                size: Size(width: 100, height: 40),
                position: [
                    Keyframe(at: 1, value: Point(x: 0, y: 0)),
                    Keyframe(at: 1.5, value: Point(x: 100, y: 0))
                ],
                anchor: Point(x: 0, y: 0)
            )
        )
        let child = fill(parent: "label")
        let sut = ParentEvaluator(sequence: sequence(clips: [parent, child]))

        // When
        let space = sut.space(of: child, at: time)

        // Then
        #expect(isClose(space.transform, AffineTransform(translation: Point(x: x, y: 0))))
    }

    @Test("an unparented clip is in output pixels")
    func leavesUnparentedClip() {
        // Given
        let child = fill(parent: nil)
        let sut = ParentEvaluator(sequence: sequence(clips: [child]))

        // When
        let space = sut.space(of: child, at: 1)

        // Then
        #expect(space.transform == .identity)
        #expect(space.clock == nil)
    }

    // MARK: - Private
    private func sequence(
        clips: [ResolvedClip],
        crop: [Keyframe<Crop>]? = nil
    ) -> ResolvedSequence {
        let push = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 1]), SpanKey(t: 1, values: [.x: 0])])

        return ResolvedSequence(
            format: ResolvedFormat(size: size, fps: 10, duration: 4, background: red, conform: .fit),
            storyline: [
                ResolvedStorylineClip(
                    place: "storyline[0]",
                    id: "shot",
                    media: .pinned(media),
                    solid: nil,
                    in: 0,
                    out: 2,
                    speed: 1,
                    start: 0,
                    end: 2,
                    crop: crop ?? [Keyframe(at: 0, value: Crop(whole))],
                    track: nil,
                    filter: .off,
                    transition: nil,
                    filling: size
                ),
                ResolvedStorylineClip(
                    place: "storyline[1]",
                    id: "next",
                    media: nil,
                    solid: red,
                    in: 0,
                    out: 2,
                    speed: 1,
                    start: 2,
                    end: 4,
                    crop: [],
                    track: nil,
                    filter: .off,
                    transition: ResolvedTransition(
                        start: 1.5,
                        end: 2.5,
                        over: .incoming,
                        incoming: push,
                        outgoing: nil,
                        cover: nil,
                        matte: nil
                    ),
                    filling: size
                )
            ],
            clips: clips,
            audio: []
        )
    }

    private func fill(parent: String?) -> ResolvedClip {
        clip(
            id: "child",
            content: .shape(ResolvedShape(
                area: [Keyframe(at: 0, value: Rectangle(x: 0, y: 0, width: 10, height: 10))],
                fill: red
            )),
            parent: parent
        )
    }

    // A 100 x 40 title anchored at its bottom centre, its box's top left at `position`.
    private func title(
        id: String,
        parent: String?,
        position: Point,
        scale: Double
    ) -> ResolvedClip {
        clip(
            id: id,
            content: .title(text),
            parent: parent,
            box: ResolvedBox(
                size: Size(width: 100, height: 40),
                position: [Keyframe(at: 0, value: position)],
                anchor: Point(x: 50, y: 40)
            ),
            scale: scale
        )
    }

    private func clip(
        id: String,
        content: ResolvedClipContent,
        start: Double = 0,
        end: Double = 4,
        parent: String? = nil,
        mask: [Keyframe<[ResolvedMask]>]? = nil,
        box: ResolvedBox? = nil,
        crop: [Keyframe<Crop>]? = nil,
        track: ResolvedTrack? = nil,
        scale: Double = 1
    ) -> ResolvedClip {
        ResolvedClip(
            place: "clips[0]",
            id: id,
            content: content,
            start: start,
            end: end,
            lane: 1,
            storyline: nil,
            parent: parent,
            box: box,
            crop: crop,
            mask: mask,
            trackMatte: nil,
            track: track,
            opacity: [Keyframe(at: 0, value: 1)],
            scale: box == nil ? nil : [Keyframe(at: 0, value: scale)],
            rotation: box == nil ? nil : [Keyframe(at: 0, value: 0)],
            blend: "normal",
            animation: .none
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
