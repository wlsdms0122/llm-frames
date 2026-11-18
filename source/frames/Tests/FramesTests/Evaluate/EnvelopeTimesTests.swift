//
//  EnvelopeTimesTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

@testable import Frames
import Testing

@Suite("EnvelopeTimes Tests")
struct EnvelopeTimesTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("keyframes of equal values hold, so they bend at each keyframe and move nowhere")
    func holdsBetweenEqualKeyframes() {
        // Given
        let sut = EnvelopeTimes(keyframes: [
            Keyframe(at: 0, value: 0.5, ease: .easeInOut),
            Keyframe(at: 1, value: 0.5, ease: .easeInOut),
            Keyframe(at: 2, value: 0.5)
        ])

        // When
        let times = sut.times(over: TimeRange(start: 0, end: 3), fps: 10)

        // Then
        #expect(sut.moving.isEmpty)
        #expect(times == [0, 1, 2, 3])
    }

    @Test("keyframes of different values move between them, sampled at every frame time")
    func movesBetweenDifferentKeyframes() {
        // Given
        let sut = EnvelopeTimes(keyframes: [
            Keyframe(at: 0, value: 0.5),
            Keyframe(at: 1, value: 0.5),
            Keyframe(at: 1.5, value: 1)
        ])

        // When
        let times = sut.times(over: TimeRange(start: 0, end: 2), fps: 4)

        // Then
        #expect(sut.moving == [TimeRange(start: 1, end: 1.5)])
        #expect(times == [0, 1, 1.25, 1.5, 2])
    }

    @Test("a ramp moves over its whole range, and its frames outside the envelope's range are left out")
    func samplesRampInsideRange() {
        // Given
        let sut = EnvelopeTimes(ramps: [TimeRange(start: 0.5, end: 1.5)])

        // When
        let times = sut.times(over: TimeRange(start: 1, end: 2), fps: 4)

        // Then
        #expect(times == [1, 1.25, 1.5, 2])
    }
}
