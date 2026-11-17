//
//  EvaluatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("Evaluator Tests")
struct EvaluatorTests {
    // MARK: - Property
    private let sut = Evaluator()

    private let size = Size(width: 200, height: 100)
    private let content = Rectangle(x: 0, y: 0, width: 200, height: 100)
    private let background = Color(written: "#000000")
    private let transparent = Color(written: "#00000000")
    private let white = Color(written: "#FFFFFF")
    private let red = Color(written: "#FF0000")
    // The whole of a 400 x 200 picture, already the content rect's aspect ratio.
    private let whole = Rectangle(x: 0, y: 0, width: 400, height: 200)
    // From the whole picture at 0 to its middle 200 x 100 at 2.
    private let zoom = [
        Keyframe(at: 0, value: Crop(Rectangle(x: 0, y: 0, width: 400, height: 200))),
        Keyframe(at: 2, value: Crop(Rectangle(x: 100, y: 50, width: 200, height: 100)))
    ]
    // Frames every quarter second from 0 to 4.75.
    private let first = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/first.mp4", sha256: String(repeating: "a", count: 64))),
        frameTimes: (0..<20).map { Double($0) / 4 }
    )
    private let second = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/second.mp4", sha256: String(repeating: "b", count: 64))),
        frameTimes: (0..<20).map { Double($0) / 4 }
    )
    // What the storyline entries of these tests are named by, and a clip of each kind drawn at `clips[0]`.
    private let videoEntry = ItemOrigin(place: "storyline", id: nil, kind: "video")
    private let fillOrigin = ItemOrigin(place: "clips[0]", id: nil, kind: "fill")

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "at a cut the outgoing clip shows before the edit point and the incoming one from it, at their media times",
        arguments: [(1.9, 0, 11, 19), (2.0, 1, 0, 20), (2.5, 1, 2, 25)]
    )
    func cutsAtEditPoint(time: Double, entry: Int, frame: Int, seed: Int) {
        // Given
        let sequence = sequence([
            storylineClip(.pinned(first), in: 1, start: 0, end: 2),
            storylineClip(.pinned(second), in: 0, start: 2, end: 4)
        ])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: time)

        // Then
        let media = [first, second][entry]
        #expect(list == DisplayList(
            size: size,
            background: background,
            seed: seed,
            items: [unitItem([mediaItem(media, frame: frame)], seed: seed), outsideItem()]
        ))
    }

    @Test(
        "during a transition the incoming unit moves and fades by its span, above the outgoing one unless `over` says",
        arguments: [TransitionOrder.incoming, .outgoing]
    )
    func stacksTransitionUnits(over: TransitionOrder) {
        // Given
        let incoming = Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.opacity: 0, .x: 1]),
            SpanKey(t: 1, values: [.opacity: 1, .x: 0])
        ])
        let sequence = transitionSequence(ResolvedTransition(
            start: 1.5,
            end: 2.5,
            over: over,
            incoming: incoming,
            outgoing: nil,
            cover: nil,
            matte: nil
        ))

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1.75)

        // Then
        // Progress 0.25: opacity 0.25 and x 0.75 of the content rect's 200 wide. The outgoing clip plays its media
        // from 1 at 0, so 2.75, and the incoming one starts 0.25 before its `in` of 1, so 0.75.
        let outgoingUnit = unitItem([mediaItem(first, frame: 11)], seed: 17)
        let incomingUnit = unitItem(
            [mediaItem(second, frame: 3)],
            seed: 17,
            transform: AffineTransform(translation: Point(x: 150, y: 0)),
            opacity: 0.25
        )
        let units = over == .incoming ? [outgoingUnit, incomingUnit] : [incomingUnit, outgoingUnit]
        #expect(list.items == units + [outsideItem()])
    }

    @Test("a colour cover fills the content rect over both units at the opacity its keys give")
    func coversWithColor() {
        // Given
        let span = Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.opacity: 0]),
            SpanKey(t: 0.5, values: [.opacity: 1]),
            SpanKey(t: 1, values: [.opacity: 0])
        ])
        let sequence = transitionSequence(ResolvedTransition(
            start: 1.5,
            end: 2.5,
            over: .incoming,
            incoming: nil,
            outgoing: nil,
            cover: ResolvedCover(source: .color(white), span: span),
            matte: nil
        ))

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1.75)

        // Then
        #expect(list.items == [
            unitItem([mediaItem(first, frame: 11)], seed: 17),
            unitItem([mediaItem(second, frame: 3)], seed: 17),
            DisplayItem(opacity: 0.5, content: .fill(FillItem(rectangle: content, color: white))),
            outsideItem()
        ])
    }

    @Test("each item names the clip that drew it, and a transition cover and the background outside the content rect none")
    func namesDrawingClips() {
        // Given
        let cover = ResolvedCover(source: .color(white), span: Span(ease: .linear, keys: []))
        let transition = ResolvedTransition(
            start: 1.5,
            end: 2.5,
            over: .incoming,
            incoming: nil,
            outgoing: nil,
            cover: cover,
            matte: nil
        )
        let sequence = sequence(
            [
                storylineClip(.pinned(first), in: 1, start: 0, end: 2),
                storylineClip(nil, solid: red, start: 2, end: 4, transition: transition)
            ],
            clips: [fillClip(Rectangle(x: 0, y: 0, width: 10, height: 10), lane: 1)]
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1.75)

        // Then
        let solid = ItemOrigin(place: "storyline", id: nil, kind: "solid")
        #expect(list.items.map(\.origin) == [videoEntry, solid, nil, nil, fillOrigin])
        #expect(displayList(of: list.items[1])?.items.map(\.origin) == [solid])
    }

    @Test("a cover video and a matte show their frames at progress times their duration, the matte's progress eased")
    func picksCoverAndMatteFrames() {
        // Given
        let stinger = PinnedMedia(
            source: .file(PinnedFile(path: "/abs/stinger.mov", sha256: String(repeating: "c", count: 64))),
            frameTimes: [0, 0.5, 1, 1.5]
        )
        let wipe = PinnedMedia(
            source: .file(PinnedFile(path: "/abs/wipe.mp4", sha256: String(repeating: "d", count: 64))),
            frameTimes: (0..<8).map { Double($0) / 8 }
        )
        let cover = ResolvedCover(
            source: .media(ResolvedTransitionMedia(media: stinger, duration: 2)),
            span: Span(ease: .linear, keys: [SpanKey(t: 0, values: [.opacity: 1])])
        )
        let matte = ResolvedMatte(
            media: ResolvedTransitionMedia(media: wipe, duration: 1),
            softness: 0.1,
            isInverted: true,
            ease: .easeIn
        )
        let sequence = transitionSequence(ResolvedTransition(
            start: 1.5,
            end: 2.5,
            over: .incoming,
            incoming: nil,
            outgoing: nil,
            cover: cover,
            matte: matte
        ))

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1.75)

        // Then
        // Progress 0.25: the stinger at 0.5 of its 2 seconds, the wipe at 0.25 of its 1, and 0.25 eased in is 0.25^3.
        let pictureMatte = PictureMatte(
            frame: MediaFrame(media: wipe, index: 2),
            progress: 0.015625,
            softness: 0.1,
            isInverted: true
        )
        let coverPicture = PictureItem(
            source: .media(MediaFrame(media: stinger, index: 1)),
            rectangle: nil,
            destination: content
        )
        #expect(list.items == [
            unitItem([mediaItem(first, frame: 11)], seed: 17),
            unitItem([mediaItem(second, frame: 3)], seed: 17, matte: pictureMatte),
            DisplayItem(content: .picture(coverPicture)),
            outsideItem()
        ])
    }

    @Test("an outgoing handle past the end of the media holds its last frame")
    func holdsLastFrameInHandle() {
        // Given
        let sequence = sequence([
            storylineClip(.pinned(first), in: 3, start: 0, end: 1.75),
            storylineClip(.pinned(second), in: 0, start: 1.75, end: 3.75, transition: ResolvedTransition(
                start: 1.25,
                end: 2.25,
                over: .incoming,
                incoming: nil,
                outgoing: nil,
                cover: nil,
                matte: nil
            ))
        ])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 2)

        // Then
        // The outgoing clip would show media time 5, past its last frame at 4.75.
        #expect(list.items == [
            unitItem([mediaItem(first, frame: 19)], seed: 20),
            unitItem([mediaItem(second, frame: 1)], seed: 20),
            outsideItem()
        ])
    }

    @Test("a clip at speed 2 shows its media from `in` at twice the sequence's pace, with its resolved filter")
    func playsAtSpeed() {
        // Given
        let filter: [ResolvedFilterOperation] = [
            .lut(file: PinnedFile(path: "/abs/look.cube", sha256: String(repeating: "e", count: 64)), amount: 0.5)
        ]
        let sequence = sequence([storylineClip(.pinned(first), in: 1, speed: 2, start: 0, end: 2, filter: filter)])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 0.5)

        // Then
        #expect(list.items == [unitItem([mediaItem(first, frame: 8, filter: filter)], seed: 5), outsideItem()])
    }

    @Test("a still shows its one frame at any time")
    func showsStill() {
        // Given
        let file = PinnedFile(path: "/abs/still.png", sha256: String(repeating: "f", count: 64))
        let still = PinnedMedia(source: .file(file))
        let sequence = sequence([storylineClip(.pinned(still), start: 0, end: 3)])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1.3)

        // Then
        let entry = ItemOrigin(place: "storyline", id: nil, kind: "image")
        #expect(list.items == [
            unitItem([mediaItem(still, frame: 0, origin: entry)], seed: 13, origin: entry),
            outsideItem()
        ])
    }

    @Test("a solid fills its whole unit with its colour")
    func fillsSolid() {
        // Given
        let sequence = sequence([storylineClip(nil, solid: red, start: 0, end: 3)])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        let entry = ItemOrigin(place: "storyline", id: nil, kind: "solid")
        let fill = DisplayItem(content: .fill(FillItem(rectangle: content, color: red)), origin: entry)
        #expect(list.items == [unitItem([fill], seed: 10, origin: entry), outsideItem()])
    }

    @Test("a compound clip is its nested sequence evaluated at the clip's media time, with the outer seed")
    func evaluatesCompoundClip() {
        // Given
        let nestedContent = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let nested = nestedSequence()
        let crop = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let sequence = sequence([storylineClip(.nested(.sequence(nested)), in: 1, start: 0, end: 2, crop: crop)])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 0.5)

        // Then
        // Media time 1.5 in the nested sequence shows its clip's frame at 1.5.
        let nestedList = DisplayList(
            size: Size(width: 100, height: 50),
            background: red,
            seed: 5,
            items: [
                unitItem([mediaItem(first, frame: 6, in: nestedContent)], seed: 5, content: nestedContent),
                outsideItem(size: Size(width: 100, height: 50), content: nestedContent, color: red)
            ]
        )
        let picture = PictureItem(source: .displayList(nestedList), rectangle: crop, destination: content)
        let entry = ItemOrigin(place: "storyline", id: nil, kind: "compound")
        #expect(list.items == [
            unitItem([DisplayItem(content: .picture(picture), origin: entry)], seed: 5, origin: entry),
            outsideItem()
        ])
    }

    @Test("a tracked crop's keyframes are brought back to the instant at their own times and carried to the time shown")
    func carriesTrackedCrop() throws {
        // Given
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 0, isBand: false, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 20, y: 0, width: 10, height: 10)),
            TrackedFrame(time: 2, rectangle: Rectangle(x: 40, y: 0, width: 10, height: 10))
        ])
        let crop = [
            Keyframe(at: 0, value: Crop(Rectangle(x: 0, y: 0, width: 100, height: 50))),
            Keyframe(at: 2, value: Crop(Rectangle(x: 50, y: 0, width: 100, height: 50)))
        ]
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4, crop: crop, track: track)])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        // The second keyframe is 40 to the right of the target at 2, so 10 at the instant. Halfway is 5, carried 20
        // by the motion at 1.
        let rectangle = try #require(mediaPicture(of: list)?.rectangle)
        #expect(isClose(rectangle, Rectangle(x: 25, y: 0, width: 100, height: 50)))
    }

    @Test("a tracked band crop keeps its full width and takes only the vertical part of the motion")
    func carriesTrackedBand() throws {
        // Given
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 0, isBand: true, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 30, y: 20, width: 10, height: 10))
        ])
        let sequence = sequence([
            storylineClip(
                .pinned(first),
                start: 0,
                end: 4,
                crop: Rectangle(x: 0, y: 0, width: 200, height: 100),
                track: track
            )
        ])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        let rectangle = try #require(mediaPicture(of: list)?.rectangle)
        #expect(rectangle == Rectangle(x: 0, y: 20, width: 200, height: 100))
    }

    @Test("a tracked band crop takes the vertical move of a zooming target but not its scale, so it keeps its ratio")
    func keepsBandCropRatio() throws {
        // Given
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 0, isBand: true, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 20, y: 20, width: 20, height: 20))
        ])
        let sequence = sequence([
            storylineClip(
                .pinned(first),
                start: 0,
                end: 4,
                crop: Rectangle(x: 0, y: 0, width: 200, height: 100),
                track: track
            )
        ])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        // The target's centre moves down from 5 to 30 and it doubles, but the crop only moves.
        let rectangle = try #require(mediaPicture(of: list)?.rectangle)
        #expect(rectangle == Rectangle(x: 0, y: 25, width: 200, height: 100))
    }

    @Test("a `fit` crop beyond the picture is drawn as conformed, leaving what lies outside the picture transparent")
    func drawsCropBeyondPicture() throws {
        // Given
        let crop = Rectangle(x: -100, y: 0, width: 600, height: 300)
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4, crop: crop)])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 0.5)

        // Then
        let picture = try #require(mediaPicture(of: list))
        #expect(picture.rectangle == crop)
        #expect(picture.destination == content)
    }

    @Test("under an inset the unit fills the content rect and the background the rest, with the content rect as hole")
    func fillsOutsideContentRect() {
        // Given
        let inset = Rectangle(x: 20, y: 10, width: 160, height: 80)
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], content: inset)

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 0.5)

        // Then
        #expect(list.items == [
            unitItem([mediaItem(first, frame: 2, in: inset)], seed: 5, content: inset),
            DisplayItem(content: .fill(FillItem(
                rectangle: Rectangle(x: 0, y: 0, width: 200, height: 100),
                color: background,
                hole: RoundedRectangle(rectangle: inset, radius: 0)
            )))
        ])
    }

    @Test("frame k has seed k, and every list nested in it carries the same seed")
    func seedsNestedLists() throws {
        // Given
        let crop = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let sequence = sequence(
            [storylineClip(.nested(.sequence(nestedSequence())), start: 0, end: 2, crop: crop)],
            fps: 25
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 7.0 / 25)

        // Then
        let unit = try #require(displayList(of: list.items.first))
        let nested = try #require(displayList(of: unit.items.first))
        let nestedUnit = try #require(displayList(of: nested.items.first))
        #expect([list.seed, unit.seed, nested.seed, nestedUnit.seed] == [7, 7, 7, 7])
    }

    @Test("an image document's steps become items in order, each cut to its step's canvas and named by what drew it")
    func drawsImageSteps() {
        // Given
        let canvas = Rectangle(x: 0, y: 0, width: 300, height: 200)
        let inner = Rectangle(x: 10, y: 10, width: 280, height: 180)
        let badge = ResolvedPicture(kind: "image", size: Size(width: 50, height: 50), steps: [
            step(
                "ops[0].media.ops[0]",
                "pad",
                .fill(Rectangle(x: 0, y: 0, width: 50, height: 50), color: red),
                clip: canvas
            )
        ])
        let text = ResolvedText(
            size: Size(width: 100, height: 40),
            lineCount: 1,
            background: TextBackground(color: red, padding: Size(width: 8, height: 4), radius: 5),
            stroke: TextStroke(width: 2, color: background),
            runs: [run()]
        )
        let picture = ResolvedPicture(kind: "image", size: Size(width: 300, height: 200), steps: [
            step(
                "source",
                "image",
                .picture(.media(first, time: 0.6), crop: whole, frame: Rectangle(x: 0, y: 0, width: 300, height: 150)),
                clip: canvas
            ),
            step(
                "ops[0]",
                "title",
                .picture(
                    .picture(badge),
                    crop: Rectangle(x: 0, y: 0, width: 50, height: 50),
                    frame: Rectangle(x: 10, y: 10, width: 50, height: 50)
                ),
                clip: canvas
            ),
            step("ops[1]", "pad", .fill(Rectangle(x: 0, y: 150, width: 300, height: 50), color: white), clip: canvas),
            ResolvedDrawingStep(
                place: "ops[2]#serial",
                id: "serial",
                kind: "box",
                content: .box(Rectangle(x: 20, y: 20, width: 100, height: 50), width: 4, radius: 6, color: red),
                clip: canvas
            ),
            step(
                "ops[3]",
                "border",
                .border(Rectangle(x: 10, y: 10, width: 100, height: 50), width: 4, color: white),
                clip: canvas
            ),
            step(
                "ops[4]",
                "dim",
                .dim(Rectangle(x: 50, y: 50, width: 100, height: 50), color: background),
                clip: inner
            ),
            step(
                "ops[5]",
                "arrow",
                .arrow(tail: Point(x: 0, y: 0), tip: Point(x: 40, y: 30), width: 3, head: 12, color: red),
                clip: canvas
            ),
            step(
                "ops[6]",
                "adjust",
                .adjustment([.blur(radius: 2)], area: Rectangle(x: 0, y: 0, width: 150, height: 100)),
                clip: canvas
            ),
            step("ops[7]", "title", .text(text, frame: Rectangle(x: 10, y: 20, width: 200, height: 80)), clip: inner)
        ])

        // When
        let early = sut.displayList(of: .picture(picture), at: 0)
        let late = sut.displayList(of: .picture(picture), at: 3.7)

        // Then
        let badgeList = DisplayList(size: Size(width: 50, height: 50), background: transparent, seed: 0, items: [
            DisplayItem(
                mask: canvas,
                content: .fill(FillItem(rectangle: Rectangle(x: 0, y: 0, width: 50, height: 50), color: red)),
                origin: ItemOrigin(place: "ops[0].media.ops[0]", id: nil, kind: "pad")
            )
        ])
        let expected = DisplayList(size: Size(width: 300, height: 200), background: transparent, seed: 0, items: [
            DisplayItem(
                mask: canvas,
                content: .picture(PictureItem(
                    source: .media(MediaFrame(media: first, index: 2)),
                    rectangle: whole,
                    destination: Rectangle(x: 0, y: 0, width: 300, height: 150)
                )),
                origin: ItemOrigin(place: "source", id: nil, kind: "image")
            ),
            DisplayItem(
                mask: canvas,
                content: .picture(PictureItem(
                    source: .displayList(badgeList),
                    rectangle: Rectangle(x: 0, y: 0, width: 50, height: 50),
                    destination: Rectangle(x: 10, y: 10, width: 50, height: 50)
                )),
                origin: ItemOrigin(place: "ops[0]", id: nil, kind: "title")
            ),
            DisplayItem(
                mask: canvas,
                content: .fill(FillItem(rectangle: Rectangle(x: 0, y: 150, width: 300, height: 50), color: white)),
                origin: ItemOrigin(place: "ops[1]", id: nil, kind: "pad")
            ),
            DisplayItem(
                mask: canvas,
                content: .stroke(StrokeItem(
                    rectangle: Rectangle(x: 20, y: 20, width: 100, height: 50),
                    radius: 6,
                    width: 4,
                    color: red
                )),
                origin: ItemOrigin(place: "ops[2]#serial", id: "serial", kind: "box")
            ),
            DisplayItem(
                mask: canvas,
                content: .stroke(StrokeItem(
                    rectangle: Rectangle(x: 12, y: 12, width: 96, height: 46),
                    radius: 0,
                    width: 4,
                    color: white
                )),
                origin: ItemOrigin(place: "ops[3]", id: nil, kind: "border")
            ),
            DisplayItem(
                mask: inner,
                content: .fill(FillItem(
                    rectangle: inner,
                    color: background,
                    hole: RoundedRectangle(rectangle: Rectangle(x: 50, y: 50, width: 100, height: 50), radius: 0)
                )),
                origin: ItemOrigin(place: "ops[4]", id: nil, kind: "dim")
            ),
            DisplayItem(
                mask: canvas,
                content: .arrow(ArrowItem(
                    tail: Point(x: 0, y: 0),
                    head: Point(x: 40, y: 30),
                    width: 3,
                    headSize: 12,
                    color: red
                )),
                origin: ItemOrigin(place: "ops[5]", id: nil, kind: "arrow")
            ),
            DisplayItem(
                mask: canvas,
                content: .adjust(AdjustItem(
                    rectangle: Rectangle(x: 0, y: 0, width: 150, height: 100),
                    filter: [.blur(radius: 2)]
                )),
                origin: ItemOrigin(place: "ops[6]", id: nil, kind: "adjust")
            ),
            DisplayItem(
                transform: AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 10, ty: 20),
                mask: inner,
                content: .glyphs(GlyphsItem(
                    size: Size(width: 100, height: 40),
                    runs: [run()],
                    stroke: TextStroke(width: 2, color: background),
                    background: GlyphBackground(
                        rectangle: Rectangle(x: 0, y: 0, width: 100, height: 40),
                        radius: 5,
                        color: red
                    )
                )),
                origin: ItemOrigin(place: "ops[7]", id: nil, kind: "title")
            )
        ])
        #expect(early == expected)
        #expect(late == expected)
    }

    @Test("a compound clip drawn by a picture step is evaluated at its time held inside its duration, with seed 0")
    func holdsCompoundStepTime() {
        // Given
        let nestedContent = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let canvas = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let picture = ResolvedPicture(kind: "layout", size: Size(width: 100, height: 50), steps: [
            step(
                "items[0]",
                "layout item",
                .picture(.sequence(nestedSequence(), time: 5), crop: nestedContent, frame: canvas),
                clip: canvas
            )
        ])

        // When
        let list = sut.displayList(of: .picture(picture), at: 0)

        // Then
        // The nested sequence lasts 3, so time 5 is held just before 3, on its clip's frame at 2.75.
        let nestedList = DisplayList(
            size: Size(width: 100, height: 50),
            background: red,
            seed: 0,
            items: [
                unitItem([mediaItem(first, frame: 11, in: nestedContent)], seed: 0, content: nestedContent),
                outsideItem(size: Size(width: 100, height: 50), content: nestedContent, color: red)
            ]
        )
        #expect(list.items == [
            DisplayItem(
                mask: canvas,
                content: .picture(PictureItem(
                    source: .displayList(nestedList),
                    rectangle: nestedContent,
                    destination: canvas
                )),
                origin: ItemOrigin(place: "items[0]", id: nil, kind: "layout item")
            )
        ])
    }

    @Test("clips stack by lane and then document order: unparented below and above the units, parented inside theirs")
    func stacksClipsByLane() {
        // Given
        // Each fill is told apart by its area. Parented areas are in the 400 x 200 picture, shown at half size.
        let sequence = sequence(
            [storylineClip(.pinned(first), start: 0, end: 4)],
            clips: [
                fillClip(Rectangle(x: 0, y: 0, width: 10, height: 10), lane: 2),
                fillClip(Rectangle(x: 10, y: 0, width: 10, height: 10), lane: -1),
                fillClip(Rectangle(x: 20, y: 0, width: 10, height: 10), lane: 1),
                fillClip(Rectangle(x: 0, y: 0, width: 20, height: 20), lane: 1, storyline: 0, isParented: true),
                fillClip(Rectangle(x: 20, y: 0, width: 20, height: 20), lane: -1, storyline: 0, isParented: true),
                fillClip(Rectangle(x: 40, y: 0, width: 20, height: 20), lane: -2, storyline: 0, isParented: true),
                fillClip(Rectangle(x: 30, y: 0, width: 10, height: 10), lane: 1, start: 3),
                fillClip(Rectangle(x: 40, y: 0, width: 10, height: 10), lane: 2)
            ]
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        #expect(list.items == [
            fillItem(Rectangle(x: 10, y: 0, width: 10, height: 10)),
            unitItem(
                [
                    fillItem(Rectangle(x: 20, y: 0, width: 10, height: 10)),
                    fillItem(Rectangle(x: 10, y: 0, width: 10, height: 10)),
                    mediaItem(first, frame: 4),
                    fillItem(Rectangle(x: 0, y: 0, width: 10, height: 10))
                ],
                seed: 10
            ),
            outsideItem(),
            fillItem(Rectangle(x: 20, y: 0, width: 10, height: 10)),
            fillItem(Rectangle(x: 0, y: 0, width: 10, height: 10)),
            fillItem(Rectangle(x: 40, y: 0, width: 10, height: 10))
        ])
    }

    @Test(
        "a parented box follows its picture's zooming crop, and its stroke keeps its width in output pixels",
        arguments: [
            (0.0, Rectangle(x: 75, y: 37.5, width: 20, height: 10)),
            (2.0, Rectangle(x: 50, y: 25, width: 40, height: 20))
        ]
    )
    func followsZoomingCrop(
        time: Double,
        area: Rectangle
    ) throws {
        // Given
        let sequence = sequence(
            [storylineClip(.pinned(first), start: 0, end: 4, crop: zoom)],
            clips: [
                clip(
                    .shape(.box(width: 4, radius: 2, color: red)),
                    storyline: 0,
                    isParented: true,
                    area: [Keyframe(at: 0, value: Rectangle(x: 150, y: 75, width: 40, height: 20))]
                )
            ]
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: time)

        // Then
        // The crop is the whole picture at 0, shown at half size, and 200 x 100 from (100, 50) at 2, at full size.
        let unit = try #require(displayList(of: list.items.first))
        guard case let .stroke(stroke) = unit.items.last?.content else {
            Issue.record("a box is a stroke")
            return
        }
        #expect(isClose(stroke.rectangle, area))
        #expect(stroke.width == 4)
        #expect(stroke.radius == 2)
    }

    @Test(
        "a parented title keeps its size under a zoom, its anchor point staying on its place in the picture",
        arguments: [(0.0, Point(x: 50, y: 27.5)), (2.0, Point(x: 30, y: 15))]
    )
    func keepsParentedTitleSize(
        time: Double,
        position: Point
    ) throws {
        // Given
        // The anchor point is (160, 75) in the picture: (80, 37.5) in the unit at half size, (60, 25) at full size.
        let text = text(Size(width: 60, height: 20))
        let box = ResolvedBox(
            size: Size(width: 60, height: 20),
            position: [Keyframe(at: 0, value: Point(x: 130, y: 65))],
            anchor: Point(x: 30, y: 10)
        )
        let sequence = sequence(
            [storylineClip(.pinned(first), start: 0, end: 4, crop: zoom)],
            clips: [clip(.title(text), storyline: 0, isParented: true, box: box)]
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: time)

        // Then
        let unit = try #require(displayList(of: list.items.first))
        let item = try #require(unit.items.last)
        let transform = item.transform
        #expect([transform.a, transform.b, transform.c, transform.d] == [1, 0, 0, 1])
        #expect(abs(transform.tx - position.x) < 1e-9 && abs(transform.ty - position.y) < 1e-9)
        #expect(item.content == .glyphs(GlyphsItem(text: text)))
    }

    @Test("a tracked box on a scrolling picture is where each keyframe puts it at its own time, carried by the scroll")
    func carriesTrackedArea() throws {
        // Given
        // The page scrolls up 40 a second. The second keyframe is 40 right of the first where it is at 2, so at the
        // instant it lies 40 right of the first and halfway is (120, 100), scrolled up 40 at 1.
        let target = Rectangle(x: 100, y: 100, width: 40, height: 20)
        let track = ResolvedTrack(target: target, mediaTime: 0, isBand: false, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 100, y: 60, width: 40, height: 20)),
            TrackedFrame(time: 2, rectangle: Rectangle(x: 100, y: 20, width: 40, height: 20))
        ])
        let area = [
            Keyframe(at: 0, value: target),
            Keyframe(at: 2, value: Rectangle(x: 140, y: 20, width: 40, height: 20))
        ]
        let sequence = sequence(
            [storylineClip(.pinned(first), start: 0, end: 4)],
            clips: [clip(.shape(.fill(color: red)), storyline: 0, isParented: true, area: area, track: track)]
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        let unit = try #require(displayList(of: list.items.first))
        #expect(unit.items.last == fillItem(Rectangle(x: 60, y: 30, width: 20, height: 10)))
    }

    @Test("a tracked band keeps the full width of its picture and takes the vertical move and scale of its height")
    func carriesTrackedBandArea() throws {
        // Given
        // The target's centre moves from (120, 110) to (120, 55) and it grows 1.5 times.
        let target = Rectangle(x: 100, y: 100, width: 40, height: 20)
        let track = ResolvedTrack(target: target, mediaTime: 0, isBand: true, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 90, y: 40, width: 60, height: 30))
        ])
        let band = Rectangle(x: 0, y: 100, width: 400, height: 20)
        let sequence = sequence(
            [storylineClip(.pinned(first), start: 0, end: 4)],
            clips: [
                clip(
                    .shape(.fill(color: red)),
                    storyline: 0,
                    isParented: true,
                    area: [Keyframe(at: 0, value: band)],
                    track: track
                )
            ]
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        // The band is (0, 40, 400, 30) in the picture, half that in the unit.
        let unit = try #require(displayList(of: list.items.first))
        #expect(unit.items.last == fillItem(Rectangle(x: 0, y: 20, width: 200, height: 15)))
    }

    @Test("a media clip narrowed by tracking shows nothing before its start and plays from `in` at its `origin`")
    func playsNarrowedMediaFromOrigin() throws {
        // Given
        let media = mediaClip(timing: ResolvedMediaTiming(in: 0, origin: 1, out: 4, speed: 1, loop: false), start: 1.5)
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [media])

        // When
        let early = sut.displayList(of: .sequence(sequence), at: 1.25)
        let late = sut.displayList(of: .sequence(sequence), at: 2)

        // Then
        // At 2 the clip is one second past its origin, on the second media's frame at 1.
        #expect(early.items.count == 2)
        #expect(clipPicture(of: late)?.source == .media(MediaFrame(media: second, index: 4)))
    }

    @Test(
        "past `out` a looping media clip repeats from `in`, and any other holds its last frame",
        arguments: [(true, 2), (false, 5)]
    )
    func loopsMediaClip(
        loop: Bool,
        frame: Int
    ) {
        // Given
        // At 1 the clip at speed 2 reaches media time 2.5, a second past `out` 1.5, and one loop of 1 brings it back
        // to `in` 0.5.
        let media = mediaClip(timing: ResolvedMediaTiming(in: 0.5, origin: 0, out: 1.5, speed: 2, loop: loop))
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [media])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        #expect(clipPicture(of: list)?.source == .media(MediaFrame(media: second, index: frame)))
    }

    @Test("a media clip draws its conformed crop into its box, with its filter, radius, border, shadow and blend")
    func drawsMediaClip() {
        // Given
        let border = MediaBorder(width: 2, color: white)
        let shadow = MediaShadow(radius: 4, offset: Point(x: 0, y: 2), color: background)
        let media = mediaClip(
            timing: nil,
            filter: [.blur(radius: 2)],
            appearance: ResolvedMediaAppearance(conform: .fit, radius: 6, border: border, shadow: shadow),
            blend: "screen"
        )
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [media])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        // A still shows its frame 0, and its box's top left goes to the position.
        #expect(list.items.last == DisplayItem(
            transform: AffineTransform(translation: Point(x: 10, y: 20)),
            blend: "screen",
            content: .picture(PictureItem(
                source: .media(MediaFrame(media: second, index: 0)),
                rectangle: Rectangle(x: 0, y: 0, width: 400, height: 200),
                destination: Rectangle(x: 0, y: 0, width: 80, height: 40),
                filter: [.blur(radius: 2)],
                radius: 6,
                border: border,
                shadow: shadow
            )),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "video")
        ))
    }

    @Test("a parented adjustment is drawn inside its unit over its mapped area, so it reaches only that unit")
    func keepsParentedAdjustmentInUnit() throws {
        // Given
        let adjustment = clip(
            .adjustment([.blur(radius: 3)]),
            storyline: 0,
            isParented: true,
            area: [Keyframe(at: 0, value: Rectangle(x: 0, y: 0, width: 200, height: 100))],
            opacity: 0.5
        )
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [adjustment])

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        let adjust = DisplayItem(
            opacity: 0.5,
            content: .adjust(AdjustItem(rectangle: Rectangle(x: 0, y: 0, width: 100, height: 50), filter: [.blur(radius: 3)])),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "adjustment")
        )
        #expect(list.items == [unitItem([mediaItem(first, frame: 4), adjust], seed: 10), outsideItem()])
    }

    @Test("a dim without an area darkens the content rect for a connected clip and the output frame for a sequence clip")
    func dimsRoomOfClip() {
        // Given
        let inset = Rectangle(x: 20, y: 10, width: 160, height: 80)
        let sequence = sequence(
            [storylineClip(.pinned(first), start: 0, end: 4)],
            clips: [
                clip(.shape(.dim(color: background)), storyline: 0),
                clip(.shape(.dim(color: background)))
            ],
            content: inset
        )

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 1)

        // Then
        let rooms = list.items.suffix(2).map { item -> Rectangle? in
            guard case let .fill(fill) = item.content else { return nil }
            return fill.rectangle
        }
        #expect(rooms == [inset, Rectangle(x: 0, y: 0, width: 200, height: 100)])
    }

    @Test("a connected adjustment without an area under an inset filters, moves and wipes the whole output frame")
    func adjustsWholeFrameOfConnectedClip() {
        // Given
        let inset = Rectangle(x: 20, y: 10, width: 160, height: 80)
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .left, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ]))
        let adjustment = clip(
            .adjustment([.blur(radius: 2)]),
            storyline: 0,
            animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil)
        )
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [adjustment], content: inset)

        // When
        let list = sut.displayList(of: .sequence(sequence), at: 0.5)

        // Then
        // Halfway through its entrance the wipe shows the left half of the 200 x 100 output frame, letterbox and all,
        // since the filter reaches the whole output.
        #expect(list.items.last == DisplayItem(
            reveal: Rectangle(x: 0, y: 0, width: 100, height: 100),
            content: .adjust(AdjustItem(rectangle: nil, filter: [.blur(radius: 2)])),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "adjustment")
        ))
    }

    @Test("a resolved label's box at the time its side was chosen lies on that side of its box, inside the content rect")
    func agreesWithResolvedLabelSide() throws {
        // Given
        // The crop zooms in two times over the clip, so at the label's instant the box is shown through a crop
        // between the two.
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3,
                "keyframes": [ { "at": 1, "crop": [0, 0, 1206, 2622] }, { "at": 3, "crop": [301.5, 655.5, 603, 1311] } ],
                "connected": [ { "shape": "box", "area": [700, 1250, 300, 40], "at": [2, 3], "label": "Total",
                    "animation": "none", "labelAnimation": "none" } ] } ] }
            """#
        let resolved = try ResolvedDocument(
            plan: Fixture.documentPlanner.plan(Fixture.json(document)),
            hashes: FileHashTable()
        )
        guard case let .sequence(sequence) = resolved else {
            Issue.record("a sequence resolves to a sequence")
            return
        }
        let clip = try #require(sequence.clips.first)
        let label = try #require(clip.label)
        let content = sequence.format.content

        // When
        let list = sut.displayList(of: resolved, at: label.at)

        // Then
        let unit = try #require(displayList(of: list.items.first))
        let shape = try #require(unit.items.dropLast().last)
        let labelItem = try #require(unit.items.last)
        guard case let .stroke(stroke) = shape.content else {
            Issue.record("a box is a stroke")
            return
        }
        let size = label.text.size
        let corners = labelItem.transform.apply(toCornersOf: Rectangle(x: 0, y: 0, width: size.width, height: size.height))
        let drawn = Rectangle(
            x: corners[0].x + content.x,
            y: corners[0].y + content.y,
            width: corners[2].x - corners[0].x,
            height: corners[2].y - corners[0].y
        )
        let box = Rectangle(
            x: stroke.rectangle.x + content.x,
            y: stroke.rectangle.y + content.y,
            width: stroke.rectangle.width,
            height: stroke.rectangle.height
        )
        #expect(isClose(drawn, LabelSideFinder().rectangle(of: size, beside: box, on: label.side)))
        #expect(content.contains(drawn))
    }

    // MARK: - Private
    private func step(
        _ place: String,
        _ kind: String,
        _ content: ResolvedDrawingContent,
        clip: Rectangle
    ) -> ResolvedDrawingStep {
        ResolvedDrawingStep(place: place, id: nil, kind: kind, content: content, clip: clip)
    }

    private func storylineClip(
        _ media: ResolvedMediaContent?,
        solid: Color? = nil,
        in: Double = 0,
        speed: Double = 1,
        start: Double,
        end: Double,
        crop: Rectangle? = nil,
        track: ResolvedTrack? = nil,
        filter: [ResolvedFilterOperation] = [],
        transition: ResolvedTransition? = nil
    ) -> ResolvedStorylineClip {
        storylineClip(
            media,
            solid: solid,
            in: `in`,
            speed: speed,
            start: start,
            end: end,
            crop: [Keyframe(at: start, value: Crop(crop ?? whole))],
            track: track,
            filter: filter,
            transition: transition
        )
    }

    private func storylineClip(
        _ media: ResolvedMediaContent?,
        solid: Color? = nil,
        in: Double = 0,
        speed: Double = 1,
        start: Double,
        end: Double,
        crop: [Keyframe<Crop>],
        track: ResolvedTrack? = nil,
        filter: [ResolvedFilterOperation] = [],
        transition: ResolvedTransition? = nil
    ) -> ResolvedStorylineClip {
        ResolvedStorylineClip(
            place: "storyline",
            id: nil,
            media: media,
            solid: solid,
            in: `in`,
            out: `in` + (end - start) * speed,
            speed: speed,
            start: start,
            end: end,
            crop: crop,
            track: track,
            filter: filter,
            transition: transition
        )
    }

    private func sequence(
        _ storyline: [ResolvedStorylineClip],
        clips: [ResolvedClip] = [],
        content: Rectangle? = nil,
        fps: Double = 10
    ) -> ResolvedSequence {
        ResolvedSequence(
            format: ResolvedFormat(
                size: size,
                fps: fps,
                duration: storyline.last?.end ?? 0,
                background: background,
                content: content ?? self.content,
                conform: .fit
            ),
            storyline: storyline,
            clips: clips,
            audio: []
        )
    }

    // A fill drawn on an area, its place a sequence clip's.
    private func fillClip(
        _ area: Rectangle,
        lane: Int,
        storyline: Int? = nil,
        isParented: Bool = false,
        start: Double = 0
    ) -> ResolvedClip {
        clip(
            .shape(.fill(color: red)),
            start: start,
            lane: lane,
            storyline: storyline,
            isParented: isParented,
            area: [Keyframe(at: 0, value: area)]
        )
    }

    private func clip(
        _ content: ResolvedClipContent,
        start: Double = 0,
        end: Double = 4,
        lane: Int = 1,
        storyline: Int? = nil,
        isParented: Bool = false,
        area: [Keyframe<Rectangle>]? = nil,
        box: ResolvedBox? = nil,
        crop: [Keyframe<Crop>]? = nil,
        track: ResolvedTrack? = nil,
        opacity: Double = 1,
        blend: String = "normal",
        animation: ResolvedAnimation = .none
    ) -> ResolvedClip {
        let isAdjustment = if case .adjustment = content { true } else { false }

        return ResolvedClip(
            place: "clips[0]",
            id: nil,
            content: content,
            start: start,
            end: end,
            lane: lane,
            storyline: storyline,
            isParented: isParented,
            area: area,
            box: box,
            crop: crop,
            track: track,
            label: nil,
            opacity: [Keyframe(at: 0, value: opacity)],
            scale: box == nil ? nil : [Keyframe(at: 0, value: 1)],
            rotation: box == nil ? nil : [Keyframe(at: 0, value: 0)],
            blend: isAdjustment ? nil : blend,
            animation: animation
        )
    }

    // A media clip of the second media, its 80 x 40 box at (10, 20) showing the whole of its 400 x 200 picture.
    private func mediaClip(
        timing: ResolvedMediaTiming?,
        start: Double = 0,
        filter: [ResolvedFilterOperation] = [],
        appearance: ResolvedMediaAppearance = ResolvedMediaAppearance(conform: .fit, radius: 0, border: nil, shadow: nil),
        blend: String = "normal"
    ) -> ResolvedClip {
        let media = ResolvedMediaClip(media: .pinned(second), timing: timing, filter: filter, appearance: appearance)
        let box = ResolvedBox(
            size: Size(width: 80, height: 40),
            position: [Keyframe(at: 0, value: Point(x: 10, y: 20))],
            anchor: Point(x: 40, y: 20)
        )

        return clip(.media(media), start: start, box: box, crop: [Keyframe(at: 0, value: Crop(whole))], blend: blend)
    }

    private func fillItem(_ rectangle: Rectangle) -> DisplayItem {
        DisplayItem(content: .fill(FillItem(rectangle: rectangle, color: red)), origin: fillOrigin)
    }

    private func text(_ size: Size) -> ResolvedText {
        ResolvedText(size: size, lineCount: 1, background: nil, stroke: nil, runs: [run()])
    }

    // The picture of the list's topmost item.
    private func clipPicture(of list: DisplayList) -> PictureItem? {
        guard case let .picture(picture) = list.items.last?.content else { return nil }

        return picture
    }

    // The first clip plays from 1 over 0 to 2, and the second, from 1 over 2 to 4, is brought in by the transition.
    private func transitionSequence(_ transition: ResolvedTransition) -> ResolvedSequence {
        sequence([
            storylineClip(.pinned(first), in: 1, start: 0, end: 2),
            storylineClip(.pinned(second), in: 1, start: 2, end: 4, transition: transition)
        ])
    }

    // A 100 x 50 sequence of 3 seconds on a red background, playing the first media from 0.
    private func nestedSequence() -> ResolvedSequence {
        ResolvedSequence(
            format: ResolvedFormat(
                size: Size(width: 100, height: 50),
                fps: 30,
                duration: 3,
                background: red,
                content: Rectangle(x: 0, y: 0, width: 100, height: 50),
                conform: .fit
            ),
            storyline: [storylineClip(.pinned(first), start: 0, end: 3)],
            clips: [],
            audio: []
        )
    }

    private func unitItem(
        _ items: [DisplayItem],
        seed: Int,
        content: Rectangle? = nil,
        transform: AffineTransform = .identity,
        opacity: Double = 1,
        matte: PictureMatte? = nil,
        origin: ItemOrigin? = nil
    ) -> DisplayItem {
        let content = content ?? self.content
        let unit = Rectangle(x: 0, y: 0, width: content.width, height: content.height)
        let list = DisplayList(
            size: Size(width: content.width, height: content.height),
            background: transparent,
            seed: seed,
            items: items
        )

        let picture = PictureItem(source: .displayList(list), rectangle: unit, destination: content, matte: matte)

        return DisplayItem(
            transform: transform,
            opacity: opacity,
            mask: content,
            content: .picture(picture),
            origin: origin ?? videoEntry
        )
    }

    private func mediaItem(
        _ media: PinnedMedia,
        frame: Int,
        filter: [ResolvedFilterOperation] = [],
        in content: Rectangle? = nil,
        origin: ItemOrigin? = nil
    ) -> DisplayItem {
        let content = content ?? self.content
        let picture = PictureItem(
            source: .media(MediaFrame(media: media, index: frame)),
            rectangle: whole,
            destination: Rectangle(x: 0, y: 0, width: content.width, height: content.height),
            filter: filter
        )

        return DisplayItem(content: .picture(picture), origin: origin ?? videoEntry)
    }

    private func outsideItem(
        size: Size? = nil,
        content: Rectangle? = nil,
        color: Color? = nil
    ) -> DisplayItem {
        let size = size ?? self.size
        let fill = FillItem(
            rectangle: Rectangle(x: 0, y: 0, width: size.width, height: size.height),
            color: color ?? background,
            hole: RoundedRectangle(rectangle: content ?? self.content, radius: 0)
        )

        return DisplayItem(content: .fill(fill))
    }

    private func run() -> ResolvedGlyphRun {
        ResolvedGlyphRun(
            font: PinnedFile(path: "/abs/font.ttf", sha256: String(repeating: "0", count: 64)),
            face: "Font-Bold",
            size: 30,
            color: white,
            glyphs: [PositionedGlyph(id: 1, x: 8, y: 34)]
        )
    }

    // The nested list a picture item shows, nil for any other item.
    private func displayList(of item: DisplayItem?) -> DisplayList? {
        guard case let .picture(picture) = item?.content,
            case let .displayList(list) = picture.source
        else { return nil }

        return list
    }

    // The media picture of the list's first unit.
    private func mediaPicture(of list: DisplayList) -> PictureItem? {
        guard case let .picture(picture) = displayList(of: list.items.first)?.items.first?.content else { return nil }

        return picture
    }

    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        [rectangle.x - other.x, rectangle.y - other.y, rectangle.width - other.width, rectangle.height - other.height]
            .allSatisfy { abs($0) < 1e-9 }
    }
}
