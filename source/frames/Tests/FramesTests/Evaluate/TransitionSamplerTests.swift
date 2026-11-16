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
    // Centred on (540, 1110).
    private let content = Rectangle(x: 40, y: 420, width: 1000, height: 1380)

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

    @Test("a unit's offset is in multiples of the content rect")
    func offsetsByContentRect() {
        // Given
        let span = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.y: 1]), SpanKey(t: 1, values: [.y: 0])])

        // When
        let unit = sut.unit(moving: span, in: content, at: 0.25)

        // Then
        #expect(unit.transform == AffineTransform(translation: Point(x: 0, y: 1035)))
        #expect(unit.opacity == 1)
        #expect(unit.reveal == nil)
    }

    @Test("a unit scales about the centre of the content rect")
    func scalesAboutContentCenter() {
        // Given
        let span = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.scale: 0.5]), SpanKey(t: 1, values: [.scale: 1])])

        // When
        let unit = sut.unit(moving: span, in: content, at: 0)

        // Then
        #expect(unit.transform.apply(to: Point(x: 540, y: 1110)) == Point(x: 540, y: 1110))
        #expect(unit.transform.apply(to: Point(x: 40, y: 420)) == Point(x: 290, y: 765))
    }

    @Test("a unit's reveal shows the content rect from its span's side")
    func revealsContentRect() {
        // Given
        let span = Span(ease: .linear, revealFrom: .right, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ])

        // When
        let unit = sut.unit(moving: span, in: content, at: 0.25)

        // Then
        #expect(unit.reveal == Rectangle(x: 790, y: 420, width: 250, height: 1380))
    }

    @Test("each span bends the transition's progress by its own ease")
    func easesEachSpan() {
        // Given
        let span = Span(ease: .easeIn, keys: [SpanKey(t: 0, values: [.opacity: 0]), SpanKey(t: 1, values: [.opacity: 1])])

        // When
        let unit = sut.unit(moving: span, in: content, at: 0.5)

        // Then
        #expect(unit.opacity == 0.125)
    }

    @Test("a unit the transition gives no motion stays still and whole")
    func unitWithoutSpanStays() {
        // Given
        let span: Span? = nil

        // When
        let unit = sut.unit(moving: span, in: content, at: 0.5)

        // Then
        #expect(unit.transform.apply(toCornersOf: content) == AffineTransform.identity.apply(toCornersOf: content))
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
