//
//  AnimationSamplerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("AnimationSampler Tests")
struct AnimationSamplerTests {
    // MARK: - Property
    private let sut = AnimationSampler()
    // Fades in over 0.5 seconds, grows from 1 to 2 every second, and fades out over 0.5 seconds.
    private let entrance = AnimationSpan(length: 0.5, span: Span(ease: .linear, revealFrom: .top, keys: [
        SpanKey(t: 0, values: [.opacity: 0, .reveal: 0]),
        SpanKey(t: 1, values: [.opacity: 1, .reveal: 1])
    ]))
    private let loop = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [
        SpanKey(t: 0, values: [.scale: 1]),
        SpanKey(t: 1, values: [.scale: 2])
    ]))
    private let exit = AnimationSpan(length: 0.5, span: Span(ease: .linear, keys: [
        SpanKey(t: 0, values: [.opacity: 1]),
        SpanKey(t: 1, values: [.opacity: 0])
    ]))

    // MARK: - Initializer
    // MARK: - Test
    @Test("the entrance runs for its seconds from the window start, revealing from its own side")
    func runsEntrance() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: 2.25)

        // Then
        #expect(sample.motion.value(of: .opacity) == 0.5)
        #expect(sample.motion.value(of: .scale) == 1)
        #expect(sample.reveal == Reveal(amount: 0.5, edge: .top))
    }

    @Test(
        "the loop repeats every period from the end of the entrance",
        arguments: [(3.0, 1.5), (4.75, 1.25), (5.25, 1.75)]
    )
    func repeatsLoop(time: Double, scale: Double) {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: time)

        // Then
        #expect(abs(sample.motion.value(of: .scale) - scale) < 1e-9)
        #expect(sample.motion.value(of: .opacity) == 1)
    }

    @Test("the exit runs for the last seconds of the window, and the loop stops at its start")
    func runsExit() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: 5.75)

        // Then
        #expect(sample.motion.value(of: .opacity) == 0.5)
        #expect(sample.motion.value(of: .scale) == 1)
    }

    @Test("on a short window the entrance runs first and the exit plays whole in the time that is left")
    func shortWindowShortensExit() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: nil, exit: exit)
        let window = TimeRange(start: 0, end: 0.8)

        // When
        let entering = sut.sample(of: animation, in: window, at: 0.25)
        let leaving = sut.sample(of: animation, in: window, at: 0.65)

        // Then
        #expect(entering.motion.value(of: .opacity) == 0.5)
        #expect(abs(leaving.motion.value(of: .opacity) - 0.5) < 1e-9)
    }

    @Test("a window shorter than the entrance cuts the entrance at its end and leaves the exit no time")
    func windowShorterThanEntrance() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: nil, exit: exit)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 0, end: 0.4), at: 0.3)

        // Then
        #expect(abs(sample.motion.value(of: .opacity) - 0.6) < 1e-9)
    }

    @Test("each span's ease bends its progress")
    func easesSpan() {
        // Given
        let eased = AnimationSpan(length: 1, span: Span(ease: .easeIn, keys: entrance.span.keys))
        let animation = ResolvedAnimation(entrance: eased, loop: nil, exit: nil)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 0, end: 4), at: 0.5)

        // Then
        #expect(sample.motion.value(of: .opacity) == 0.125)
    }

    @Test(
        "outside every span, and outside the window, the clip simply shows",
        arguments: [1.5, 3.0, 6.0]
    )
    func showsOutsideSpans(time: Double) {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: nil, exit: exit)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: time)

        // Then
        #expect(sample == .none)
    }

    @Test("a clip with no spans simply shows")
    func showsWithoutSpans() {
        // Given
        let animation = ResolvedAnimation.none

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 0, end: 4), at: 1)

        // Then
        #expect(sample == .none)
        #expect(sample.reveal == .full)
    }
}
