//
//  UnitSamplerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// The entrance fades a unit in over 1 second and the exit fades it out over 1 second, and the loop moves the title
// right by its width over 1 second.
@Suite("Unit sampler Tests")
struct UnitSamplerTests {
    // MARK: - Property
    private let sut = UnitSampler()
    private let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [
        SpanKey(t: 0, values: [.opacity: 0]),
        SpanKey(t: 1, values: [.opacity: 1])
    ]))
    private let loop = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [
        SpanKey(t: 0, values: [.x: 0]),
        SpanKey(t: 1, values: [.x: 1])
    ]))
    private let exit = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [
        SpanKey(t: 0, values: [.opacity: 1]),
        SpanKey(t: 1, values: [.opacity: 0])
    ]))

    // MARK: - Initializer
    // MARK: - Test
    @Test("unit i enters from s + i × stagger and leaves from e - x - (n - 1 - i) × stagger, the loop between them")
    func schedulesUnits() {
        // When
        let schedule = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 10))

        // Then
        #expect([0, 1, 2].map(schedule.entranceStart) == [0, 0.5, 1])
        #expect([0, 1, 2].map(schedule.exitStart) == [8, 8.5, 9])
        #expect(schedule.rest == TimeRange(start: 2, end: 8))
    }

    @Test("on a short window the exit's seconds and stagger are scaled by (e - s - E) / X, and there is none when E fills it")
    func scalesTheExitOnAShortWindow() {
        // When
        let short = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 3))
        let filled = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 2))

        // Then
        #expect(short.exit == 0.5)
        #expect(short.exitStagger == 0.25)
        #expect([0, 1, 2].map(short.exitStart) == [2, 2.25, 2.5])
        #expect(filled.exit == 0)
        #expect(sut.unit(2, of: animation(), schedule: filled, at: 1.5).motion.value(of: .opacity) == 0.5)
    }

    @Test("a unit holds its entrance at progress 0 before its turn and its exit at progress 1 after it")
    func holdsUnitsOutsideTheirSpans() {
        // Given
        let schedule = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 10))
        let opacity = { (index: Int, time: Double) in
            sut.unit(index, of: animation(), schedule: schedule, at: time).motion.value(of: .opacity)
        }

        // Then
        #expect([opacity(0, 0.5), opacity(1, 0.5), opacity(2, 0.5)] == [0.5, 0, 0])
        #expect([opacity(0, 5), opacity(1, 5), opacity(2, 5)] == [1, 1, 1])
        #expect([opacity(0, 9.5), opacity(1, 9.5), opacity(2, 9.5)] == [0, 0, 0.5])
    }

    @Test("the loop plays on the whole title from the last unit's entrance end to the first unit's exit start")
    func loopsTheWholeTitle() {
        // Given
        let schedule = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 10))
        let x = { (time: Double) in sut.title(of: animation(), schedule: schedule, at: time).motion.value(of: .x) }

        // Then
        #expect([x(1.5), x(2.25), x(7.5), x(8.5)] == [0, 0.25, 0.5, 0])
    }

    @Test("a unit's instant past the window's end from T stands at its last pose, and T outside the window takes none")
    func holdsUnitAtWindowEnd() {
        // Given
        let schedule = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 10))

        // When
        let pastEnd = sut.unit(2, of: animation(), schedule: schedule, at: 10.01, onSideOf: 9.99)
        let outside = sut.unit(2, of: animation(), schedule: schedule, at: 9.99, onSideOf: 10.01)

        // Then
        #expect(pastEnd == sut.unit(2, of: animation(), schedule: schedule, at: schedule.window.held(10.01)))
        #expect(outside == .none)
    }

    @Test("the title's loop is read through its seam as it is")
    func readsTitleLoopThroughSeam() {
        // Given
        let schedule = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 10))

        // When
        let sample = sut.title(of: animation(), schedule: schedule, at: 3.01, onSideOf: 2.99)

        // Then
        #expect(abs(sample.motion.value(of: .x) - 0.01) < 1e-9)
    }

    @Test("in a sample of a frame with motion blur, a unit's reveal is set by an entrance or exit that writes it, and the title's by a loop that does")
    func setsRevealInSample() {
        // Given
        let wipe = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ]))
        let unitWipe = ResolvedAnimation(entrance: wipe, loop: loop, exit: exit, units: UnitStagger(by: .word, stagger: 0.5))
        let loopWipe = ResolvedAnimation(entrance: entrance, loop: wipe, exit: exit, units: UnitStagger(by: .word, stagger: 0.5))
        let schedule = schedule(count: 3, stagger: 0.5, window: TimeRange(start: 0, end: 10))
        let sampled = SampleTime(instant: 5, frameTime: 5, sample: SampleInstant(instant: 5, frameTime: 5, reads: MotionBlurReads()))

        // When
        let unitOfUnitWipe = sut.unit(0, of: unitWipe, schedule: schedule, at: sampled)
        let titleOfUnitWipe = sut.title(of: unitWipe, schedule: schedule, at: sampled)
        let unitOfLoopWipe = sut.unit(0, of: loopWipe, schedule: schedule, at: sampled)
        let titleOfLoopWipe = sut.title(of: loopWipe, schedule: schedule, at: sampled)
        let outsideSample = sut.unit(0, of: unitWipe, schedule: schedule, at: SampleTime(0.5))

        // Then
        #expect(unitOfUnitWipe.isRevealSet)
        #expect(!titleOfUnitWipe.isRevealSet)
        #expect(!unitOfLoopWipe.isRevealSet)
        #expect(titleOfLoopWipe.isRevealSet)
        #expect(!outsideSample.isRevealSet)
    }

    // MARK: - Private
    private func animation() -> ResolvedAnimation {
        ResolvedAnimation(entrance: entrance, loop: loop, exit: exit, units: UnitStagger(by: .word, stagger: 0.5))
    }

    private func schedule(
        count: Int,
        stagger: Double,
        window: TimeRange
    ) -> UnitSchedule {
        UnitSchedule(animation: animation(), stagger: stagger, count: count, in: window)
    }
}
