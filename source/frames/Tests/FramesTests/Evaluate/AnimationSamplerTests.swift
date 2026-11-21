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
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit, units: nil)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: 2.25)

        // Then
        #expect(sample.motion.value(of: .opacity) == 0.5)
        #expect(sample.motion.value(of: .scale) == 1)
        #expect(sample.reveal == Reveal(amount: 0.5))
        #expect(sample.revealFrom == .top)
    }

    @Test(
        "the loop repeats every period from the end of the entrance",
        arguments: [(3.0, 1.5), (4.75, 1.25), (5.25, 1.75)]
    )
    func repeatsLoop(time: Double, scale: Double) {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit, units: nil)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: time)

        // Then
        #expect(abs(sample.motion.value(of: .scale) - scale) < 1e-9)
        #expect(sample.motion.value(of: .opacity) == 1)
    }

    @Test("the exit runs for the last seconds of the window, and the loop stops at its start")
    func runsExit() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit, units: nil)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: 5.75)

        // Then
        #expect(sample.motion.value(of: .opacity) == 0.5)
        #expect(sample.motion.value(of: .scale) == 1)
    }

    @Test("on a short window the entrance runs first and the exit plays whole in the time that is left")
    func shortWindowShortensExit() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: nil, exit: exit, units: nil)
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
        let animation = ResolvedAnimation(entrance: entrance, loop: nil, exit: exit, units: nil)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 0, end: 0.4), at: 0.3)

        // Then
        #expect(abs(sample.motion.value(of: .opacity) - 0.6) < 1e-9)
    }

    @Test("each span's ease bends its progress")
    func easesSpan() {
        // Given
        let eased = AnimationSpan(length: 1, span: Span(ease: .easeIn, keys: entrance.span.keys))
        let animation = ResolvedAnimation(entrance: eased, loop: nil, exit: nil, units: nil)

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
        let animation = ResolvedAnimation(entrance: entrance, loop: nil, exit: exit, units: nil)

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

    @Test("an instant past the window's end from T stands at the last pose, and one before its start at the first")
    func holdsWindowEnds() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit, units: nil)
        let window = TimeRange(start: 2, end: 6)

        // When
        let pastEnd = sut.sample(of: animation, in: window, at: 6.01, onSideOf: 5.99)
        let beforeStart = sut.sample(of: animation, in: window, at: 1.99, onSideOf: 2)

        // Then
        #expect(pastEnd == sut.sample(of: animation, in: window, at: window.held(6.01)))
        #expect(pastEnd != .none)
        #expect(beforeStart == sut.sample(of: animation, in: window, at: 2))
    }

    @Test("an instant of a frame whose T lies outside the window takes no motion")
    func addsNoneOutsideWindow() {
        // Given
        let animation = ResolvedAnimation(entrance: entrance, loop: loop, exit: exit, units: nil)

        // When
        let sample = sut.sample(of: animation, in: TimeRange(start: 2, end: 6), at: 2.01, onSideOf: 1.99)

        // Then
        #expect(sample == .none)
    }

    @Test("a seamless loop is read through its seam as it is, and so is the handover from the entrance to the loop")
    func readsLoopSeamAndHandover() {
        // Given
        let spin = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.rotation: 0]),
            SpanKey(t: 1, values: [.rotation: 360])
        ]))
        let animation = ResolvedAnimation(entrance: entrance, loop: spin, exit: nil, units: nil)
        let window = TimeRange(start: 2, end: 9)

        // When
        let throughSeam = sut.sample(of: animation, in: window, at: 3.51, onSideOf: 3.49)
        let throughHandover = sut.sample(of: animation, in: window, at: 2.51, onSideOf: 2.49)

        // Then
        #expect(abs(throughSeam.motion.value(of: .rotation) - 3.6) < 1e-9)
        #expect(abs(throughHandover.motion.value(of: .rotation) - 3.6) < 1e-9)
        #expect(throughHandover.motion.value(of: .opacity) == 1)
    }

    @Test("an entrance eased by step is clamped at its end, the jump the editor wrote, to T's side")
    func clampsStepEntrance() {
        // Given
        let step = AnimationSpan(length: 0.5, span: Span(ease: .step, keys: [
            SpanKey(t: 0, values: [.opacity: 0]),
            SpanKey(t: 1, values: [.opacity: 1])
        ]))
        let animation = ResolvedAnimation(entrance: step, loop: loop, exit: nil, units: nil)
        let window = TimeRange(start: 2, end: 6)

        // When
        let fromBefore = sut.sample(of: animation, in: window, at: 2.51, onSideOf: 2.49)
        let fromAfter = sut.sample(of: animation, in: window, at: 2.49, onSideOf: 2.51)

        // Then
        #expect(fromBefore.motion.value(of: .opacity) == 0)
        #expect(fromAfter == sut.sample(of: animation, in: window, at: 2.5))
    }

    @Test("across a loop seam each property is clamped by its own jumps: a double key at the seam holds one, and the other reads on")
    func clampsEachPropertyAcrossSeam() {
        // Given
        let spin = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.rotation: 0, .opacity: 1]),
            SpanKey(t: 1, values: [.rotation: 360, .opacity: 0.5]),
            SpanKey(t: 1, values: [.opacity: 1])
        ]))
        let animation = ResolvedAnimation(entrance: nil, loop: spin, exit: nil, units: nil)
        let window = TimeRange(start: 2, end: 9)

        // When
        let sample = sut.sample(of: animation, in: window, at: 3.01, onSideOf: 2.99)

        // Then
        #expect(sample.motion.value(of: .opacity) == 0.5)
        #expect(abs(sample.motion.value(of: .rotation) - 3.6) < 1e-9)
    }

    @Test("a double key of the instant's pass just after a loop seam clamps an instant past it to the first key")
    func clampsDoubleKeyAfterSeam() {
        // Given
        let blink = AnimationSpan(length: 0.1, span: Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.opacity: 0]),
            SpanKey(t: 0.1, values: [.opacity: 0.2]),
            SpanKey(t: 0.1, values: [.opacity: 0.8]),
            SpanKey(t: 1, values: [.opacity: 1])
        ]))
        let animation = ResolvedAnimation(entrance: nil, loop: blink, exit: nil, units: nil)
        let window = TimeRange(start: 2, end: 9)

        // When
        let pastJump = sut.sample(of: animation, in: window, at: 2.515, onSideOf: 2.495)
        let beforeJump = sut.sample(of: animation, in: window, at: 2.505, onSideOf: 2.495)

        // Then
        #expect(pastJump.motion.value(of: .opacity) == 0.2)
        #expect(abs(beforeJump.motion.value(of: .opacity) - 0.1) < 1e-9)
    }

    @Test("a loop eased by step ends at each seam, so an instant across its end into the exit takes T's period's start value, and one back from the exit the exit's start")
    func clampsStepLoopAtSeam() {
        // Given
        let hold = AnimationSpan(length: 0.4, span: Span(ease: .step, keys: [
            SpanKey(t: 0, values: [.scale: 3]),
            SpanKey(t: 1, values: [.scale: 4])
        ]))
        let animation = ResolvedAnimation(entrance: nil, loop: hold, exit: exit, units: nil)
        let window = TimeRange(start: 2, end: 3.3)

        // When
        let throughSeam = sut.sample(of: animation, in: window, at: 2.41, onSideOf: 2.39)
        let intoExit = sut.sample(of: animation, in: window, at: 2.81, onSideOf: 2.79)
        let fromExit = sut.sample(of: animation, in: window, at: 2.79, onSideOf: 2.81)

        // Then
        #expect(throughSeam.motion.value(of: .scale) == 3)
        #expect(intoExit.motion.value(of: .scale) == 3)
        #expect(intoExit.motion.value(of: .opacity) == 1)
        #expect(fromExit.motion.value(of: .opacity) == 1)
        #expect(fromExit.motion.value(of: .scale) == 1)
    }

    @Test(
        "a double key of a loop period that lies whole between T and the instant clamps the instant, forward to the first key and back to the second",
        arguments: [(2.008, 2.022, 0.6, 72.0), (2.022, 2.008, 0.4, 288.0)]
    )
    func clampsDoubleKeyOfPassBetween(frameTime: Double, time: Double, opacity: Double, rotation: Double) {
        // Given
        let flicker = AnimationSpan(length: 0.01, span: Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.opacity: 1, .rotation: 0]),
            SpanKey(t: 0.5, values: [.opacity: 0.6]),
            SpanKey(t: 0.5, values: [.opacity: 0.4]),
            SpanKey(t: 1, values: [.opacity: 1, .rotation: 360])
        ]))
        let animation = ResolvedAnimation(entrance: nil, loop: flicker, exit: nil, units: nil)
        let window = TimeRange(start: 2, end: 9)

        // When
        let sample = sut.sample(of: animation, in: window, at: time, onSideOf: frameTime)

        // Then
        #expect(abs(sample.motion.value(of: .opacity) - opacity) < 1e-9)
        #expect(abs(sample.motion.value(of: .rotation) - rotation) < 1e-6)
    }

    @Test("a loop period the exit takes over before its end has no step end on the way, so an instant in the exit reads it as it is")
    func readsCutPeriodIntoExit() {
        // Given
        let hold = AnimationSpan(length: 0.4, span: Span(ease: .step, keys: [
            SpanKey(t: 0, values: [.scale: 3]),
            SpanKey(t: 1, values: [.scale: 4])
        ]))
        let animation = ResolvedAnimation(entrance: nil, loop: hold, exit: exit, units: nil)
        let window = TimeRange(start: 2, end: 3.2)

        // When
        let sample = sut.sample(of: animation, in: window, at: 2.81, onSideOf: 2.69)

        // Then
        #expect(sample.motion.value(of: .scale) == 1)
        #expect(abs(sample.motion.value(of: .opacity) - 0.78) < 1e-9)
    }
}
