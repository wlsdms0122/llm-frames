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
    // Centred on (540, 960).
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
        "a unit's offset is in multiples of the frame, so x 1 moves it by one frame width",
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

        // When
        let unit = sut.unit(moving: span, in: frame, at: 0.25)

        // Then
        #expect(unit.transform == AffineTransform(translation: translation))
        #expect(unit.opacity == 1)
        #expect(unit.reveal == nil)
    }

    @Test("a unit scales about the centre of the frame")
    func scalesAboutFrameCenter() {
        // Given
        let span = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.scale: 0.5]), SpanKey(t: 1, values: [.scale: 1])])

        // When
        let unit = sut.unit(moving: span, in: frame, at: 0)

        // Then
        #expect(unit.transform.apply(to: Point(x: 540, y: 960)) == Point(x: 540, y: 960))
        #expect(unit.transform.apply(to: Point(x: 0, y: 0)) == Point(x: 270, y: 480))
    }

    @Test("a unit's reveal shows the frame from its span's side")
    func revealsFrame() {
        // Given
        let span = Span(ease: .linear, revealFrom: .right, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ])

        // When
        let unit = sut.unit(moving: span, in: frame, at: 0.25)

        // Then
        #expect(unit.reveal == Rectangle(x: 810, y: 0, width: 270, height: 1920))
    }

    @Test("each span bends the transition's progress by its own ease")
    func easesEachSpan() {
        // Given
        let span = Span(ease: .easeIn, keys: [SpanKey(t: 0, values: [.opacity: 0]), SpanKey(t: 1, values: [.opacity: 1])])

        // When
        let unit = sut.unit(moving: span, in: frame, at: 0.5)

        // Then
        #expect(unit.opacity == 0.125)
    }

    @Test("a unit the transition gives no motion stays still and whole")
    func unitWithoutSpanStays() {
        // Given
        let span: Span? = nil

        // When
        let unit = sut.unit(moving: span, in: frame, at: 0.5)

        // Then
        #expect(unit.transform.apply(toCornersOf: frame) == AffineTransform.identity.apply(toCornersOf: frame))
        #expect(unit.opacity == 1)
        #expect(unit.reveal == nil)
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
        let value = sut.coverOpacity(of: cover, at: progress)

        // Then
        #expect(abs(value - opacity) < 1e-9)
    }

    @Test("a matte's progress is the transition's progress bent by the matte's ease")
    func easesMatte() {
        // Given
        let ease = Ease.easeIn

        // When
        let value = sut.matteProgress(easedBy: ease, at: 0.5)

        // Then
        #expect(value == 0.125)
    }

    @Test("the unit over names is on top", arguments: [
        (TransitionOrder.incoming, [TransitionOrder.outgoing, .incoming]),
        (TransitionOrder.outgoing, [TransitionOrder.incoming, .outgoing])
    ])
    func stacksOverOnTop(over: TransitionOrder, bottomFirst: [TransitionOrder]) {
        // Given, When
        let order = over.bottomFirst

        // Then
        #expect(order == bottomFirst)
    }
}
