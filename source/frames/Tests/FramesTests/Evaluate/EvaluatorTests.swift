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
    private let frame = Rectangle(x: 0, y: 0, width: 200, height: 100)
    private let background = Color(written: "#000000")
    private let transparent = Color(written: "#00000000")
    private let white = Color(written: "#FFFFFF")
    private let red = Color(written: "#FF0000")
    // The whole of a 400 x 200 picture, already the frame's aspect ratio.
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
    private let shotEntry = ItemOrigin(place: "storyline", id: "shot", kind: "video")
    private let fillOrigin = ItemOrigin(place: "clips[0]", id: nil, kind: "rect")

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
        let list = sut.displayList(of: sequence, at: time)

        // Then
        let media = [first, second][entry]
        #expect(list == DisplayList(
            size: size,
            background: background,
            seed: seed,
            items: [storylineItem([mediaItem(media, frame: frame)], seed: seed)]
        ))
    }

    @Test(
        "during a transition the incoming storyline picture moves and fades by its span, above the outgoing one unless `over` says",
        arguments: [TransitionOrder.incoming, .outgoing]
    )
    func stacksTransitionPictures(over: TransitionOrder) {
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
        let list = sut.displayList(of: sequence, at: 1.75)

        // Then
        // Progress 0.25: opacity 0.25 and x 0.75 of the frame's 200 wide. The outgoing clip plays its media
        // from 1 at 0, so 2.75, and the incoming one starts 0.25 before its `in` of 1, so 0.75.
        let outgoingPicture = storylineItem([mediaItem(first, frame: 11)], seed: 17)
        let incomingPicture = storylineItem(
            [mediaItem(second, frame: 3)],
            seed: 17,
            transform: AffineTransform(translation: Point(x: 150, y: 0)),
            opacity: 0.25
        )
        let pictures = over == .incoming ? [outgoingPicture, incomingPicture] : [incomingPicture, outgoingPicture]
        #expect(list.items == pictures)
    }

    @Test("a colour cover fills the frame over both storyline pictures at the opacity its keys give")
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
        let list = sut.displayList(of: sequence, at: 1.75)

        // Then
        #expect(list.items == [
            storylineItem([mediaItem(first, frame: 11)], seed: 17),
            storylineItem([mediaItem(second, frame: 3)], seed: 17),
            DisplayItem(opacity: 0.5, content: .path(PathItem(filling: frame, color: white)))
        ])
    }

    @Test("each item names the clip that drew it, and a transition cover none")
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
        let list = sut.displayList(of: sequence, at: 1.75)

        // Then
        let solid = ItemOrigin(place: "storyline", id: nil, kind: "solid")
        #expect(list.items.map(\.origin) == [videoEntry, solid, nil, fillOrigin])
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
        let list = sut.displayList(of: sequence, at: 1.75)

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
            destination: frame
        )
        #expect(list.items == [
            storylineItem([mediaItem(first, frame: 11)], seed: 17),
            storylineItem([mediaItem(second, frame: 3)], seed: 17, matte: pictureMatte),
            DisplayItem(content: .picture(coverPicture))
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
        let list = sut.displayList(of: sequence, at: 2)

        // Then
        // The outgoing clip would show media time 5, past its last frame at 4.75.
        #expect(list.items == [
            storylineItem([mediaItem(first, frame: 19)], seed: 20),
            storylineItem([mediaItem(second, frame: 1)], seed: 20)
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
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        #expect(list.items == [storylineItem([mediaItem(first, frame: 8, filter: filter)], seed: 5)])
    }

    @Test("a remapped storyline clip shows the frame at its remapped media time, played backwards here")
    func picksRemappedFrame() {
        // Given
        let clip = ResolvedStorylineClip(
            place: "storyline",
            id: nil,
            media: .pinned(first),
            solid: nil,
            in: 0,
            out: 2,
            speed: 1,
            timeRemap: [Keyframe(at: 0, value: 4), Keyframe(at: 2, value: 0)],
            start: 0,
            end: 2,
            crop: [Keyframe(at: 0, value: Crop(whole))],
            track: nil,
            filter: [],
            transition: nil,
            filling: size
        )
        let sequence = sequence([clip])

        // When
        let early = sut.displayList(of: sequence, at: 0.5)
        let late = sut.displayList(of: sequence, at: 1.5)

        // Then
        // Media time 3 at 0.5 and 1 at 1.5, on frames every quarter second.
        #expect(early.items == [storylineItem([mediaItem(first, frame: 12)], seed: 5)])
        #expect(late.items == [storylineItem([mediaItem(first, frame: 4)], seed: 15)])
    }

    @Test("a remapped media clip holds between two keys of one value and shows its last frame past its media")
    func picksRemappedMediaClipFrame() {
        // Given
        let timeRemap = [Keyframe(at: 0, value: 1.0), Keyframe(at: 1, value: 1), Keyframe(at: 2, value: 9)]
        let media = mediaClip(timing: .remapped(origin: 0, timeRemap: timeRemap))
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [media])

        // When
        let frames = [0.2, 0.9, 3].map { time in clipPicture(of: sut.displayList(of: sequence, at: time))?.source }

        // Then
        #expect(frames == [4, 4, 19].map { .media(MediaFrame(media: second, index: $0)) })
    }

    @Test("a still shows its one frame at any time")
    func showsStill() {
        // Given
        let file = PinnedFile(path: "/abs/still.png", sha256: String(repeating: "f", count: 64))
        let still = PinnedMedia(source: .file(file))
        let sequence = sequence([storylineClip(.pinned(still), start: 0, end: 3)])

        // When
        let list = sut.displayList(of: sequence, at: 1.3)

        // Then
        let entry = ItemOrigin(place: "storyline", id: nil, kind: "image")
        #expect(list.items == [
            storylineItem([mediaItem(still, frame: 0, origin: entry)], seed: 13, origin: entry)
        ])
    }

    @Test("a solid fills the frame with its colour")
    func fillsSolid() {
        // Given
        let sequence = sequence([storylineClip(nil, solid: red, start: 0, end: 3)])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let entry = ItemOrigin(place: "storyline", id: nil, kind: "solid")
        let fill = DisplayItem(content: .path(PathItem(filling: frame, color: red)), origin: entry)
        #expect(list.items == [storylineItem([fill], seed: 10, origin: entry)])
    }

    @Test("a compound clip is its nested sequence evaluated at the clip's media time, with the outer seed")
    func evaluatesCompoundClip() {
        // Given
        let nestedFrame = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let nested = nestedSequence()
        let crop = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let sequence = sequence([storylineClip(.nested(nested), in: 1, start: 0, end: 2, crop: crop)])

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        // Media time 1.5 in the nested sequence shows its clip's frame at 1.5.
        let nestedList = DisplayList(
            size: Size(width: 100, height: 50),
            background: red,
            seed: 5,
            items: [storylineItem([mediaItem(first, frame: 6, in: nestedFrame)], seed: 5, frame: nestedFrame)]
        )
        let picture = PictureItem(source: .displayList(nestedList), rectangle: crop, destination: frame)
        let entry = ItemOrigin(place: "storyline", id: nil, kind: "compound")
        #expect(list.items == [
            storylineItem([DisplayItem(content: .picture(picture), origin: entry)], seed: 5, origin: entry)
        ])
    }

    @Test("a tracked crop's keyframes are brought back to the instant at their own times and carried to the time shown")
    func carriesTrackedCrop() throws {
        // Given
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 0, frames: [
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
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        // The second keyframe is 40 to the right of the target at 2, so 10 at the instant. Halfway is 5, carried 20
        // by the motion at 1.
        let rectangle = try #require(mediaPicture(of: list)?.rectangle)
        #expect(isClose(rectangle, Rectangle(x: 25, y: 0, width: 100, height: 50)))
    }

    @Test("a `fit` crop beyond the picture is drawn as conformed, leaving what lies outside the picture transparent")
    func drawsCropBeyondPicture() throws {
        // Given
        let crop = Rectangle(x: -100, y: 0, width: 600, height: 300)
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4, crop: crop)])

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        let picture = try #require(mediaPicture(of: list))
        #expect(picture.rectangle == crop)
        #expect(picture.destination == frame)
    }

    @Test("frame k has seed k, and every list nested in it carries the same seed")
    func seedsNestedLists() throws {
        // Given
        let crop = Rectangle(x: 0, y: 0, width: 100, height: 50)
        let sequence = sequence(
            [storylineClip(.nested(nestedSequence()), start: 0, end: 2, crop: crop)],
            fps: 25
        )

        // When
        let list = sut.displayList(of: sequence, at: 7.0 / 25)

        // Then
        let picture = try #require(displayList(of: list.items.first))
        let nested = try #require(displayList(of: picture.items.first))
        let nestedPicture = try #require(displayList(of: nested.items.first))
        #expect([list.seed, picture.seed, nested.seed, nestedPicture.seed] == [7, 7, 7, 7])
    }

    @Test(
        "every clip is an item of the list, by lane and then document order, the storyline between negative and positive lanes"
    )
    func stacksClipsByLane() {
        // Given
        // Each fill is told apart by its area. Parented areas are in the 400 x 200 picture, carried at half size.
        let sequence = sequence(
            [storylineClip(.pinned(first), id: "shot", start: 0, end: 4)],
            clips: [
                fillClip(Rectangle(x: 0, y: 0, width: 10, height: 10), lane: 2),
                fillClip(Rectangle(x: 10, y: 0, width: 10, height: 10), lane: -1),
                fillClip(Rectangle(x: 20, y: 0, width: 10, height: 10), lane: 1),
                fillClip(Rectangle(x: 0, y: 0, width: 20, height: 20), lane: 1, storyline: 0, parent: "shot"),
                fillClip(Rectangle(x: 20, y: 0, width: 20, height: 20), lane: -1, storyline: 0, parent: "shot"),
                fillClip(Rectangle(x: 40, y: 0, width: 20, height: 20), lane: -2, storyline: 0, parent: "shot"),
                fillClip(Rectangle(x: 30, y: 0, width: 10, height: 10), lane: 1, start: 3),
                fillClip(Rectangle(x: 40, y: 0, width: 10, height: 10), lane: 2)
            ]
        )

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let half = AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0)
        #expect(list.items == [
            fillItem(Rectangle(x: 40, y: 0, width: 20, height: 20), transform: half),
            fillItem(Rectangle(x: 10, y: 0, width: 10, height: 10)),
            fillItem(Rectangle(x: 20, y: 0, width: 20, height: 20), transform: half),
            storylineItem([mediaItem(first, frame: 4, origin: shotEntry)], seed: 10, origin: shotEntry),
            fillItem(Rectangle(x: 20, y: 0, width: 10, height: 10)),
            fillItem(Rectangle(x: 0, y: 0, width: 20, height: 20), transform: half),
            fillItem(Rectangle(x: 0, y: 0, width: 10, height: 10)),
            fillItem(Rectangle(x: 40, y: 0, width: 10, height: 10))
        ])
    }

    @Test(
        "a box parented to a storyline clip follows its zooming crop, and its stroke keeps its width in output pixels",
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
            [storylineClip(.pinned(first), id: "shot", start: 0, end: 4, crop: zoom)],
            clips: [
                clip(
                    .shape(ResolvedShape(
                        kind: .rect,
                        geometry: .area(
                            [Keyframe(at: 0, value: Rectangle(x: 150, y: 75, width: 40, height: 20))],
                            outset: 0,
                            placement: GeometryPlacement()
                        ),
                        radius: [Keyframe(at: 0, value: 2)],
                        trim: [Keyframe(at: 0, value: .whole)],
                        fill: nil,
                        stroke: PathStroke(width: 4, color: red, join: .round, cap: .butt, start: .none, end: .none),
                        shadow: nil
                    )),
                    storyline: 0,
                    parent: "shot"
                )
            ]
        )

        // When
        let list = sut.displayList(of: sequence, at: time)

        // Then
        // The crop is the whole picture at 0, shown at half size, and 200 x 100 from (100, 50) at 2, at full size.
        let item = try #require(list.items.last)
        guard
            case let .path(path) = item.content,
            case let .rect(rectangle, radius) = path.geometry,
            let stroke = path.stroke
        else {
            Issue.record("a box is a stroked rect")
            return
        }
        let corners = item.transform.apply(toCornersOf: rectangle)
        #expect(isClose(corners, area))
        #expect(abs(stroke.width * item.transform.a - 4) < 1e-9)
        #expect(abs(radius * item.transform.a - 2) < 1e-9)
    }

    @Test(
        "a title parented to a storyline clip keeps its size under a zoom, its anchor point staying on its place",
        arguments: [(0.0, Point(x: 50, y: 27.5)), (2.0, Point(x: 30, y: 15))]
    )
    func keepsParentedTitleSize(
        time: Double,
        position: Point
    ) throws {
        // Given
        // The anchor point is (160, 75) in the picture: (80, 37.5) in the output at half size, (60, 25) at full size.
        let text = text(Size(width: 60, height: 20))
        let box = ResolvedBox(
            size: Size(width: 60, height: 20),
            position: [Keyframe(at: 0, value: Point(x: 130, y: 65))],
            anchor: Point(x: 30, y: 10)
        )
        let sequence = sequence(
            [storylineClip(.pinned(first), id: "shot", start: 0, end: 4, crop: zoom)],
            clips: [clip(.title(text), storyline: 0, parent: "shot", box: box)]
        )

        // When
        let list = sut.displayList(of: sequence, at: time)

        // Then
        let item = try #require(list.items.last)
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
        let track = ResolvedTrack(target: target, mediaTime: 0, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 100, y: 60, width: 40, height: 20)),
            TrackedFrame(time: 2, rectangle: Rectangle(x: 100, y: 20, width: 40, height: 20))
        ])
        let area = [
            Keyframe(at: 0, value: target),
            Keyframe(at: 2, value: Rectangle(x: 140, y: 20, width: 40, height: 20))
        ]
        let sequence = sequence(
            [storylineClip(.pinned(first), id: "shot", start: 0, end: 4)],
            clips: [clip(.shape(ResolvedShape(area: area, fill: red)), storyline: 0, parent: "shot", track: track)]
        )

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        // (120, 100, 40, 20) at the instant, carried up 40 by the motion and then at half size.
        let carried = AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: -20)
        #expect(list.items.last == fillItem(Rectangle(x: 120, y: 100, width: 40, height: 20), transform: carried))
    }

    @Test("a media clip narrowed by tracking shows nothing before its start and plays from `in` at its `origin`")
    func playsNarrowedMediaFromOrigin() throws {
        // Given
        let played = PlayedRange(map: TimeMap(origin: 1, in: 0, speed: 1), out: 4, loop: false)
        let media = mediaClip(timing: .played(played), start: 1.5)
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [media])

        // When
        let early = sut.displayList(of: sequence, at: 1.25)
        let late = sut.displayList(of: sequence, at: 2)

        // Then
        // At 2 the clip is one second past its origin, on the second media's frame at 1.
        #expect(early.items.count == 1)
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
        let played = PlayedRange(map: TimeMap(origin: 0, in: 0.5, speed: 2), out: 1.5, loop: loop)
        let media = mediaClip(timing: .played(played))
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [media])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        #expect(clipPicture(of: list)?.source == .media(MediaFrame(media: second, index: frame)))
    }

    @Test("a media clip draws its conformed crop into its box, with its filter, radius, border, shadow and blend")
    func drawsMediaClip() {
        // Given
        let border = MediaBorder(width: 2, color: white)
        let shadow = DropShadow(radius: 4, offset: Point(x: 0, y: 2), color: background)
        let media = mediaClip(
            timing: nil,
            filter: [.blur(radius: 2)],
            appearance: ResolvedMediaAppearance(conform: .fit, radius: 6, border: border, shadow: shadow),
            blend: "screen"
        )
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [media])

        // When
        let list = sut.displayList(of: sequence, at: 1)

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

    @Test("a storyline clip's transform and opacity are on its inner item with radius, border and shadow, its blend on the outer one")
    func drawsStorylineTransform() {
        // Given
        let border = MediaBorder(width: 2, color: white)
        let shadow = DropShadow(radius: 4, offset: Point(x: 0, y: 2), color: background)
        let entry = transformed(
            storylineClip(.pinned(first), start: 0, end: 4),
            scale: [Keyframe(at: 0, value: 0.5)],
            opacity: 0.5,
            blend: "screen",
            radius: 8,
            border: border,
            shadow: shadow
        )

        // When
        let list = sut.displayList(of: sequence([entry]), at: 1)

        // Then
        // Half size about the centre of the frame, which is its anchor.
        let picture = PictureItem(
            source: .media(MediaFrame(media: first, index: 4)),
            rectangle: whole,
            destination: frame,
            radius: 8,
            border: border,
            shadow: shadow
        )
        let inner = DisplayItem(
            transform: AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 50, ty: 25),
            opacity: 0.5,
            content: .picture(picture),
            origin: videoEntry
        )
        #expect(list.items == [storylineItem([inner], seed: 10, blend: "screen")])
    }

    @Test("a storyline clip's keyframed position and scale are sampled at the time")
    func samplesStorylineTransform() {
        // Given
        let entry = transformed(
            storylineClip(.pinned(first), start: 0, end: 4),
            position: [Keyframe(at: 0, value: Point(x: 0, y: 0)), Keyframe(at: 2, value: Point(x: 100, y: 0))],
            scale: [Keyframe(at: 0, value: 1), Keyframe(at: 2, value: 0.5)]
        )

        // When
        let list = sut.displayList(of: sequence([entry]), at: 1)

        // Then
        // Scale 0.75 about the centre, then the box's top left moved to (50, 0).
        let inner = displayList(of: list.items.first)?.items.first
        #expect(inner?.transform == AffineTransform(a: 0.75, b: 0, c: 0, d: 0.75, tx: 75, ty: 12.5))
    }

    @Test("in a transition the outer item carries the motion, opacity and blend, and the inner one the clip's own transform")
    func separatesTransitionFromTransform() {
        // Given
        let incoming = Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.opacity: 0, .x: 1]),
            SpanKey(t: 1, values: [.opacity: 1, .x: 0])
        ])
        let transition = ResolvedTransition(
            start: 1.5,
            end: 2.5,
            over: .incoming,
            incoming: incoming,
            outgoing: nil,
            cover: nil,
            matte: nil
        )
        let sequence = sequence([
            storylineClip(.pinned(first), in: 1, start: 0, end: 2),
            transformed(
                storylineClip(.pinned(second), in: 1, start: 2, end: 4, transition: transition),
                scale: [Keyframe(at: 2, value: 0.5)],
                blend: "multiply"
            )
        ])

        // When
        let list = sut.displayList(of: sequence, at: 1.75)

        // Then
        let picture = PictureItem(source: .media(MediaFrame(media: second, index: 3)), rectangle: whole, destination: frame)
        let inner = DisplayItem(
            transform: AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 50, ty: 25),
            content: .picture(picture),
            origin: videoEntry
        )
        #expect(list.items == [
            storylineItem([mediaItem(first, frame: 11)], seed: 17),
            storylineItem(
                [inner],
                seed: 17,
                transform: AffineTransform(translation: Point(x: 150, y: 0)),
                opacity: 0.25,
                blend: "multiply"
            )
        ])
    }

    @Test("a child of a storyline clip follows its scale and position, after its crop")
    func movesChildWithStorylineTransform() {
        // Given
        let area = Rectangle(x: 0, y: 0, width: 20, height: 20)
        let entry = transformed(
            storylineClip(.pinned(first), id: "shot", start: 0, end: 4),
            position: [Keyframe(at: 0, value: Point(x: 20, y: 10))],
            scale: [Keyframe(at: 0, value: 0.5)]
        )
        let sequence = sequence([entry], clips: [fillClip(area, lane: 1, storyline: 0, parent: "shot")])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        // The 400 x 200 picture is half size in its box, which is half size about its centre and moved by (20, 10).
        #expect(list.items.last == fillItem(area, transform: AffineTransform(a: 0.25, b: 0, c: 0, d: 0.25, tx: 70, ty: 35)))
    }

    @Test("a child of an incoming storyline clip moves with its transition, but takes none of its opacity or reveal")
    func movesChildWithTransition() {
        // Given
        let incoming = Span(ease: .linear, revealFrom: .left, keys: [
            SpanKey(t: 0, values: [.opacity: 0, .reveal: 0, .x: 1]),
            SpanKey(t: 1, values: [.opacity: 1, .reveal: 1, .x: 0])
        ])
        let area = Rectangle(x: 0, y: 0, width: 20, height: 20)
        let sequence = sequence(
            [
                storylineClip(.pinned(first), in: 1, start: 0, end: 2),
                storylineClip(
                    .pinned(second),
                    id: "next",
                    in: 1,
                    start: 2,
                    end: 4,
                    transition: ResolvedTransition(
                        start: 1.5,
                        end: 2.5,
                        over: .incoming,
                        incoming: incoming,
                        outgoing: nil,
                        cover: nil,
                        matte: nil
                    )
                )
            ],
            clips: [fillClip(area, lane: 1, storyline: 1, parent: "next")]
        )

        // When
        let list = sut.displayList(of: sequence, at: 1.75)

        // Then
        // Progress 0.25: the picture moves 0.75 of the frame's 200 wide, and the fill, at half size in the 400 x 200
        // picture, with it.
        let moved = AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 150, ty: 0)
        #expect(list.items.last == fillItem(area, transform: moved))
    }

    @Test("a parent's opacity does not reach its child")
    func keepsChildOpacity() {
        // Given
        let area = Rectangle(x: 0, y: 0, width: 20, height: 20)
        let parent = clip(.shape(ResolvedShape(area: [Keyframe(at: 0, value: area)], fill: red)), id: "bar", opacity: 0.2)
        let child = clip(.shape(ResolvedShape(area: [Keyframe(at: 0, value: area)], fill: red)), parent: "bar")
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [parent, child])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        #expect(list.items.map(\.opacity) == [1, 0.2, 1])
    }

    @Test("a parented adjustment is an item above the storyline picture, its mask carried by its parent's map")
    func carriesParentedAdjustment() throws {
        // Given
        let adjustment = clip(
            .adjustment([.blur(radius: 3)]),
            storyline: 0,
            parent: "shot",
            mask: [Keyframe(at: 0, value: [ResolvedMask(
                geometry: .rect(Rectangle(x: 0, y: 0, width: 200, height: 100), radius: 0),
                feather: 0,
                isInverted: false,
                mode: .add
            )])],
            opacity: 0.5
        )
        let sequence = sequence([storylineClip(.pinned(first), id: "shot", start: 0, end: 4)], clips: [adjustment])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let transform = AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0)
        let adjust = DisplayItem(
            transform: transform,
            opacity: 0.5,
            mask: [ItemMask(
                geometry: .rect(Rectangle(x: 0, y: 0, width: 200, height: 100), radius: 0),
                transform: transform,
                feather: 0,
                isInverted: false,
                mode: .add
            )],
            content: .adjust(AdjustItem(filter: [.blur(radius: 3)])),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "adjustment")
        )
        let picture = storylineItem([mediaItem(first, frame: 4, origin: shotEntry)], seed: 10, origin: shotEntry)
        #expect(list.items == [picture, adjust])
    }

    @Test("a connected adjustment without a mask filters, moves and wipes the whole frame")
    func adjustsWholeFrameOfConnectedClip() {
        // Given
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .left, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ]))
        let adjustment = clip(
            .adjustment([.blur(radius: 2)]),
            storyline: 0,
            animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil)
        )
        let sequence = sequence([storylineClip(.pinned(first), start: 0, end: 4)], clips: [adjustment])

        // When
        let list = sut.displayList(of: sequence, at: 0.5)

        // Then
        // Halfway through its entrance the wipe shows the left half of the 200 x 100 frame.
        #expect(list.items.last == DisplayItem(
            reveal: Rectangle(x: 0, y: 0, width: 100, height: 100),
            content: .adjust(AdjustItem(filter: [.blur(radius: 2)])),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "adjustment")
        ))
    }

    @Test("a storyline clip's mask is on its inner item, in its media pixels carried through its crop and own transform")
    func masksStorylineInnerItem() throws {
        // Given
        let mask = ResolvedMask(geometry: .ellipse(whole), feather: 4, isInverted: false, mode: .add)
        let entry = transformed(
            storylineClip(.pinned(first), start: 0, end: 4),
            scale: [Keyframe(at: 0, value: 0.5)],
            mask: [Keyframe(at: 0, value: [mask])]
        )

        // When
        let list = sut.displayList(of: sequence([entry]), at: 1)

        // Then
        // The 400 x 200 picture is half size in its box, which is half size about the centre of the frame. The feather
        // is halved by the clip's own scale.
        let inner = try #require(displayList(of: list.items.first)?.items.first)
        let transform = AffineTransform(a: 0.25, b: 0, c: 0, d: 0.25, tx: 50, ty: 25)
        #expect(list.items.first?.mask == [])
        #expect(inner.mask == [
            ItemMask(geometry: .ellipse(whole), transform: transform, feather: 2, isInverted: false, mode: .add)
        ])
    }

    @Test("in a transition a storyline clip's mask cuts its picture before the motion, which its outer item carries")
    func cutsStorylinePictureBeforeTransition() throws {
        // Given
        let incoming = Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.x: 1]),
            SpanKey(t: 1, values: [.x: 0])
        ])
        let transition = ResolvedTransition(
            start: 1.5,
            end: 2.5,
            over: .incoming,
            incoming: incoming,
            outgoing: nil,
            cover: nil,
            matte: nil
        )
        let mask = ResolvedMask(geometry: .rect(whole, radius: 0), feather: 0, isInverted: true, mode: .add)
        let sequence = sequence([
            storylineClip(.pinned(first), in: 1, start: 0, end: 2),
            transformed(
                storylineClip(.pinned(second), in: 1, start: 2, end: 4, transition: transition),
                mask: [Keyframe(at: 2, value: [mask])]
            )
        ])

        // When
        let list = sut.displayList(of: sequence, at: 1.75)

        // Then
        // A quarter of the way in, the outer item has slid the picture three quarters of the frame to the right.
        let outer = try #require(list.items.last)
        let inner = try #require(displayList(of: outer)?.items.first)
        #expect(outer.transform == AffineTransform(translation: Point(x: 150, y: 0)))
        #expect(outer.mask == [])
        #expect(inner.mask.map(\.transform) == [AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: 0)])
    }

    @Test("a tracked storyline clip's mask keyframes are brought back at their own times and carried whole by the motion")
    func carriesTrackedStorylineMask() throws {
        // Given
        // The target moves 20 right a second and doubles in size from 1 to 2.
        let target = Rectangle(x: 0, y: 0, width: 10, height: 10)
        let track = ResolvedTrack(target: target, mediaTime: 0, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 20, y: 0, width: 10, height: 10)),
            TrackedFrame(time: 2, rectangle: Rectangle(x: 35, y: -5, width: 20, height: 20))
        ])
        let mask = [
            Keyframe(at: 0, value: [
                ResolvedMask(geometry: .ellipse(target), feather: 2, isInverted: false, mode: .add)
            ]),
            Keyframe(at: 2, value: [ResolvedMask(
                geometry: .ellipse(Rectangle(x: 55, y: -5, width: 20, height: 20)),
                feather: 2,
                isInverted: false,
                mode: .add
            )])
        ]
        let entry = transformed(storylineClip(.pinned(first), start: 0, end: 4, track: track), mask: mask)

        // When
        let list = sut.displayList(of: sequence([entry]), at: 1)

        // Then
        // At 2 the second keyframe is one target to the right of it, so (10, 0) at the instant. Halfway is (5, 0),
        // carried 20 right by the motion at 1, as the crop is: the mask lands 5 right of the crop's top left, at half
        // size in the frame.
        let inner = try #require(displayList(of: list.items.first)?.items.first)
        let itemMask = try #require(inner.mask.first)
        #expect(itemMask.geometry == .ellipse(Rectangle(x: 5, y: 0, width: 10, height: 10)))
        #expect(isClose(itemMask.transform.apply(to: Point(x: 5, y: 0)), Point(x: 2.5, y: 0)))
        #expect(isClose(itemMask.transform.apply(to: Point(x: 15, y: 10)), Point(x: 7.5, y: 5)))
        #expect(itemMask.feather == 2)
    }

    @Test("a tracked shape's mask is in its parent's media, each keyframe brought back to the instant and carried")
    func carriesTrackedShapeMask() throws {
        // Given
        // The page scrolls up 40 a second, and the second keyframe is 40 right of the first where it is at 2.
        let target = Rectangle(x: 100, y: 100, width: 40, height: 20)
        let track = ResolvedTrack(target: target, mediaTime: 0, frames: [
            TrackedFrame(time: 0, rectangle: target),
            TrackedFrame(time: 1, rectangle: Rectangle(x: 100, y: 60, width: 40, height: 20)),
            TrackedFrame(time: 2, rectangle: Rectangle(x: 100, y: 20, width: 40, height: 20))
        ])
        let mask = [
            Keyframe(at: 0, value: [
                ResolvedMask(geometry: .rect(target, radius: 0), feather: 0, isInverted: false, mode: .add)
            ]),
            Keyframe(at: 2, value: [ResolvedMask(
                geometry: .rect(Rectangle(x: 140, y: 20, width: 40, height: 20), radius: 0),
                feather: 0,
                isInverted: false,
                mode: .add
            )])
        ]
        let shape = ResolvedShape(area: [Keyframe(at: 0, value: whole)], fill: red)
        let sequence = sequence(
            [storylineClip(.pinned(first), id: "shot", start: 0, end: 4)],
            clips: [clip(.shape(shape), storyline: 0, parent: "shot", mask: mask, track: track)]
        )

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        // (120, 100, 40, 20) at the instant, carried up 40 by the motion with the shape and then at half size.
        let item = try #require(list.items.last)
        #expect(item.mask == [ItemMask(
            geometry: .rect(Rectangle(x: 120, y: 100, width: 40, height: 20), radius: 0),
            transform: AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 0, ty: -20),
            feather: 0,
            isInverted: false,
            mode: .add
        )])
    }

    // MARK: - Private
    private func storylineClip(
        _ media: ResolvedMediaContent?,
        id: String? = nil,
        solid: Color? = nil,
        in: Double = 0,
        speed: Double = 1,
        start: Double,
        end: Double,
        crop: Rectangle? = nil,
        track: ResolvedTrack? = nil,
        filter: [ResolvedFilterOperation] = [],
        transition: ResolvedTransition? = nil,
        filling frame: Size? = nil
    ) -> ResolvedStorylineClip {
        storylineClip(
            media,
            id: id,
            solid: solid,
            in: `in`,
            speed: speed,
            start: start,
            end: end,
            crop: [Keyframe(at: start, value: Crop(crop ?? whole))],
            track: track,
            filter: filter,
            transition: transition,
            filling: frame
        )
    }

    private func storylineClip(
        _ media: ResolvedMediaContent?,
        id: String? = nil,
        solid: Color? = nil,
        in: Double = 0,
        speed: Double = 1,
        start: Double,
        end: Double,
        crop: [Keyframe<Crop>],
        track: ResolvedTrack? = nil,
        filter: [ResolvedFilterOperation] = [],
        transition: ResolvedTransition? = nil,
        filling frame: Size? = nil
    ) -> ResolvedStorylineClip {
        ResolvedStorylineClip(
            place: "storyline",
            id: id,
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
            transition: transition,
            filling: frame ?? size
        )
    }

    // `entry` with its own transform, opacity, blend, box drawing and masks in place of the ones that fill the frame,
    // its anchor still the centre of the frame.
    private func transformed(
        _ entry: ResolvedStorylineClip,
        position: [Keyframe<Point>]? = nil,
        scale: [Keyframe<Double>]? = nil,
        mask: [Keyframe<[ResolvedMask]>]? = nil,
        opacity: Double = 1,
        blend: String = "normal",
        radius: Double = 0,
        border: MediaBorder? = nil,
        shadow: DropShadow? = nil
    ) -> ResolvedStorylineClip {
        ResolvedStorylineClip(
            place: entry.place,
            id: entry.id,
            media: entry.media,
            solid: entry.solid,
            in: entry.in,
            out: entry.out,
            speed: entry.speed,
            timeRemap: entry.timeRemap,
            start: entry.start,
            end: entry.end,
            crop: entry.crop,
            mask: mask,
            trackMatte: nil,
            track: entry.track,
            filter: entry.filter,
            box: ResolvedBox(size: entry.box.size, position: position ?? entry.box.position, anchor: entry.box.anchor),
            opacity: [Keyframe(at: entry.start, value: opacity)],
            scale: scale ?? entry.scale,
            rotation: entry.rotation,
            blend: blend,
            radius: radius,
            border: border,
            shadow: shadow,
            transition: entry.transition
        )
    }

    private func sequence(
        _ storyline: [ResolvedStorylineClip],
        clips: [ResolvedClip] = [],
        fps: Double = 10
    ) -> ResolvedSequence {
        ResolvedSequence(
            format: ResolvedFormat(
                size: size,
                fps: fps,
                duration: storyline.last?.end ?? 0,
                background: background,
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
        parent: String? = nil,
        start: Double = 0
    ) -> ResolvedClip {
        clip(
            .shape(ResolvedShape(area: [Keyframe(at: 0, value: area)], fill: red)),
            start: start,
            lane: lane,
            storyline: storyline,
            parent: parent
        )
    }

    private func clip(
        _ content: ResolvedClipContent,
        id: String? = nil,
        start: Double = 0,
        end: Double = 4,
        lane: Int = 1,
        storyline: Int? = nil,
        parent: String? = nil,
        mask: [Keyframe<[ResolvedMask]>]? = nil,
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
            id: id,
            content: content,
            start: start,
            end: end,
            lane: lane,
            storyline: storyline,
            parent: parent,
            box: box,
            crop: crop,
            mask: mask,
            trackMatte: nil,
            track: track,
            opacity: [Keyframe(at: 0, value: opacity)],
            scale: box == nil ? nil : [Keyframe(at: 0, value: 1)],
            rotation: box == nil ? nil : [Keyframe(at: 0, value: 0)],
            blend: isAdjustment ? nil : blend,
            animation: animation
        )
    }

    // A media clip of the second media, its 80 x 40 box at (10, 20) showing the whole of its 400 x 200 picture.
    private func mediaClip(
        timing: MediaTiming?,
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

    private func fillItem(
        _ rectangle: Rectangle,
        transform: AffineTransform = .identity
    ) -> DisplayItem {
        DisplayItem(transform: transform, content: .path(PathItem(filling: rectangle, color: red)), origin: fillOrigin)
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
                conform: .fit
            ),
            storyline: [storylineClip(.pinned(first), start: 0, end: 3, filling: Size(width: 100, height: 50))],
            clips: [],
            audio: []
        )
    }

    // A storyline picture: the outer item over the nested list of the frame's size that holds its one inner item.
    private func storylineItem(
        _ items: [DisplayItem],
        seed: Int,
        frame: Rectangle? = nil,
        transform: AffineTransform = .identity,
        opacity: Double = 1,
        blend: String = "normal",
        matte: PictureMatte? = nil,
        origin: ItemOrigin? = nil
    ) -> DisplayItem {
        let frame = frame ?? self.frame
        let list = DisplayList(
            size: Size(width: frame.width, height: frame.height),
            background: transparent,
            seed: seed,
            items: items
        )

        let picture = PictureItem(source: .displayList(list), rectangle: frame, destination: frame, matte: matte)

        return DisplayItem(
            transform: transform,
            opacity: opacity,
            blend: blend,
            content: .picture(picture),
            origin: origin ?? videoEntry
        )
    }

    private func mediaItem(
        _ media: PinnedMedia,
        frame: Int,
        filter: [ResolvedFilterOperation] = [],
        in destination: Rectangle? = nil,
        origin: ItemOrigin? = nil
    ) -> DisplayItem {
        let picture = PictureItem(
            source: .media(MediaFrame(media: media, index: frame)),
            rectangle: whole,
            destination: destination ?? self.frame,
            filter: filter
        )

        return DisplayItem(content: .picture(picture), origin: origin ?? videoEntry)
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

    // The media picture of the list's first storyline picture.
    private func mediaPicture(of list: DisplayList) -> PictureItem? {
        guard case let .picture(picture) = displayList(of: list.items.first)?.items.first?.content else { return nil }

        return picture
    }

    private func isClose(
        _ corners: [Point],
        _ rectangle: Rectangle
    ) -> Bool {
        zip(corners, AffineTransform.identity.apply(toCornersOf: rectangle))
            .allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 }
    }

    private func isClose(
        _ point: Point,
        _ other: Point
    ) -> Bool {
        abs(point.x - other.x) < 1e-9 && abs(point.y - other.y) < 1e-9
    }

    private func isClose(
        _ rectangle: Rectangle,
        _ other: Rectangle
    ) -> Bool {
        [rectangle.x - other.x, rectangle.y - other.y, rectangle.width - other.width, rectangle.height - other.height]
            .allSatisfy { abs($0) < 1e-9 }
    }
}
