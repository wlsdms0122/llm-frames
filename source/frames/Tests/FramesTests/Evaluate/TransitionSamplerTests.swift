//
//  TransitionSamplerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("TransitionSampler Tests")
struct TransitionSamplerTests {
    // MARK: - Property
    private let sut = TransitionSampler()
    private let frame = Rectangle(x: 0, y: 0, width: 1080, height: 1920)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "progress runs in a straight line through the transition and holds at its ends",
        arguments: [(10.5, 0.25), (11.0, 0.5), (9.0, 0.0), (13.0, 1.0)]
    )
    func runsProgress(time: Double, progress: Double) {
        // Given
        let range = TimeRange(start: 10, end: 12)

        // When
        let value = sut.progress(through: range, at: time)

        // Then
        #expect(value == progress)
    }

    @Test(
        "a storyline picture's offset is in multiples of the frame, so x 1 moves it by one frame width",
        arguments: [
            (MotionProperty.x, 1.0, Point(x: 1080, y: 0)),
            (MotionProperty.x, -0.5, Point(x: -540, y: 0)),
            (MotionProperty.y, 0.75, Point(x: 0, y: 1440))
        ]
    )
    func offsetsByFrame(
        property: MotionProperty,
        value: Double,
        translation: Point
    ) {
        // Given
        let span = Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [property: value]),
            SpanKey(t: 1, values: [property: value])
        ])
        let storyline = storyline(incoming: span)

        // When
        let sample = sut.motion(of: 1, in: storyline, at: 1.75)

        // Then
        let presentation = ItemPresentation(area: frame, opacity: 1, motion: sample.motion)
        #expect(presentation.transform == AffineTransform(translation: translation))
        #expect(presentation.opacity == 1)
        #expect(sample.revealRectangle(wiping: frame) == nil)
    }

    @Test("a storyline picture scales about the centre of the frame")
    func scalesAboutFrameCenter() {
        // Given
        let span = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.scale: 0.5]), SpanKey(t: 1, values: [.scale: 1])])
        let storyline = storyline(incoming: span)

        // When
        let sample = sut.motion(of: 1, in: storyline, at: 1.5)

        // Then
        let transform = ItemPresentation(area: frame, opacity: 1, motion: sample.motion).transform
        #expect(transform.apply(to: Point(x: 540, y: 960)) == Point(x: 540, y: 960))
        #expect(transform.apply(to: Point(x: 0, y: 0)) == Point(x: 270, y: 480))
    }

    @Test("a storyline picture's reveal shows the frame from its span's side")
    func revealsFrame() {
        // Given
        let span = Span(ease: .linear, revealFrom: .right, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ])
        let storyline = storyline(incoming: span)

        // When
        let sample = sut.motion(of: 1, in: storyline, at: 1.75)

        // Then
        #expect(sample.revealRectangle(wiping: frame) == Rectangle(
            x: 810,
            y: 0,
            width: 270,
            height: 1920
        ))
    }

    @Test("each span bends the transition's progress by its own ease")
    func easesEachSpan() {
        // Given
        let span = Span(ease: .easeIn, keys: [SpanKey(t: 0, values: [.opacity: 0]), SpanKey(t: 1, values: [.opacity: 1])])
        let storyline = storyline(incoming: span)

        // When
        let sample = sut.motion(of: 1, in: storyline, at: 2)

        // Then
        #expect(sample.motion.value(of: .opacity) == 0.125)
    }

    @Test("a storyline picture the transition gives no motion stays still and whole")
    func pictureWithoutSpanStays() {
        // Given
        let storyline = storyline(incoming: nil)

        // When
        let sample = sut.motion(of: 1, in: storyline, at: 2)

        // Then
        #expect(sample == .none)
    }

    @Test(
        "an entry moves by its incoming span, then by none, then by its outgoing span, held beyond its drawn range",
        arguments: [(1.0, 1.0), (2.0, 0.5), (3.0, 0.0), (4.0, -0.5), (5.0, -1.0)]
    )
    func samplesEntryMotion(time: Double, x: Double) {
        // Given
        // The middle entry is drawn from 1.5 to 4.5, coming in from the right and leaving to the left.
        let incoming = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 1]), SpanKey(t: 1, values: [.x: 0])])
        let outgoing = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 0]), SpanKey(t: 1, values: [.x: -1])])
        let storyline = storyline(incoming: incoming) + [
            entry(start: 4, end: 6, transition: transition(start: 3.5, end: 4.5, incoming: nil, outgoing: outgoing))
        ]

        // When
        let sample = sut.motion(of: 1, in: storyline, at: time)

        // Then
        #expect(sample.motion.value(of: .x) == x)
    }

    @Test("a cover's opacity follows its keys", arguments: [(0.2, 0.5), (0.4, 1.0), (0.7, 0.5)])
    func coverFollowsKeys(progress: Double, opacity: Double) {
        // Given
        let cover = Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.opacity: 0]),
            SpanKey(t: 0.4, values: [.opacity: 1]),
            SpanKey(t: 1, values: [.opacity: 0])
        ])

        // When
        let value = sut.coverOpacity(of: cover, at: SampleProgress(progress))

        // Then
        #expect(abs(value - opacity) < 1e-9)
    }

    @Test("a matte's progress is the transition's progress bent by the matte's ease")
    func easesMatte() {
        // Given
        let ease = Ease.easeIn

        // When
        let value = sut.matteProgress(easedBy: ease, at: SampleProgress(0.5))

        // Then
        #expect(value == 0.125)
    }

    @Test("the storyline picture over names is on top", arguments: [
        (TransitionOrder.incoming, [TransitionOrder.outgoing, .incoming]),
        (TransitionOrder.outgoing, [TransitionOrder.incoming, .outgoing])
    ])
    func stacksOverOnTop(over: TransitionOrder, bottomFirst: [TransitionOrder]) {
        // Given, When
        let order = over.bottomFirst

        // Then
        #expect(order == bottomFirst)
    }

    @Test("in a sample of a frame with motion blur, a transition whose span writes reveal sets the reveal, and one that does not sets none")
    func setsRevealInSample() {
        // Given
        let wipe = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.reveal: 0]), SpanKey(t: 1, values: [.reveal: 1])])
        let push = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 1]), SpanKey(t: 1, values: [.x: 0])])
        let sample = SampleInstant(instant: 2.51, frameTime: 2.49, reads: MotionBlurReads())

        // When
        let wiped = sut.motion(of: 1, in: storyline(incoming: wipe), at: sample)
        let pushed = sut.motion(of: 1, in: storyline(incoming: push), at: sample)
        let outsideSample = sut.motion(of: 1, in: storyline(incoming: wipe), at: 2.49)

        // Then
        #expect(wiped.isRevealSet)
        #expect(!pushed.isRevealSet)
        #expect(!outsideSample.isRevealSet)
    }

    // MARK: - Private
    // Two entries joined at 2 by a transition from 1.5 to 2.5 that moves the incoming one by `incoming`.
    private func storyline(incoming: Span?) -> [ResolvedStorylineClip] {
        [
            entry(start: 0, end: 2, transition: nil),
            entry(start: 2, end: 4, transition: transition(start: 1.5, end: 2.5, incoming: incoming, outgoing: nil))
        ]
    }

    private func transition(
        start: Double,
        end: Double,
        incoming: Span?,
        outgoing: Span?
    ) -> ResolvedTransition {
        ResolvedTransition(
            start: start,
            end: end,
            over: .incoming,
            incoming: incoming,
            outgoing: outgoing,
            cover: nil,
            matte: nil
        )
    }

    // A solid, which has no media to play.
    private func entry(
        start: Double,
        end: Double,
        transition: ResolvedTransition?
    ) -> ResolvedStorylineClip {
        ResolvedStorylineClip(
            place: "storyline",
            id: nil,
            content: .solid(ResolvedSolid(
                color: [Keyframe(at: start, value: Color(written: "#000000"))],
                size: Size(width: frame.width, height: frame.height),
                conform: .fit
            )),
            in: 0,
            out: end - start,
            speed: 1,
            start: start,
            end: end,
            transition: transition
        )
    }
}
