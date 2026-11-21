//
//  KeyframeTrackTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("KeyframeTrack Tests")
struct KeyframeTrackTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("before its first keyframe a property holds the first value, and after its last the last")
    func holdsEnds() {
        // Given
        let sut = KeyframeTrack(keyframes: [Keyframe(at: 2, value: 10.0), Keyframe(at: 4, value: 20.0)])

        // When
        let before = sut.value(at: 0)
        let after = sut.value(at: 9)

        // Then
        #expect(before == 10)
        #expect(after == 20)
    }

    @Test("a keyframe's ease shapes the span leaving it")
    func easesLeavingSpan() {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 0, value: 0.0, ease: .easeIn),
            Keyframe(at: 1, value: 8.0),
            Keyframe(at: 2, value: 16.0)
        ])

        // When
        let eased = sut.value(at: 0.5)
        let linear = sut.value(at: 1.5)

        // Then
        #expect(eased == 1)
        #expect(linear == 12)
    }

    @Test("keyframes are taken in time order whatever order they are written in")
    func sortsByTime() {
        // Given
        let sut = KeyframeTrack(keyframes: [Keyframe(at: 4, value: 20.0), Keyframe(at: 2, value: 10.0)])

        // When
        let value = sut.value(at: 3)

        // Then
        #expect(value == 15)
    }

    @Test("points and areas interpolate per component")
    func interpolatesPerComponent() {
        // Given
        let points = KeyframeTrack(keyframes: [Keyframe(at: 3, value: Point(x: 600, y: 500)), Keyframe(at: 4, value: Point(x: 330, y: 900))])
        let areas = KeyframeTrack(keyframes: [
            Keyframe(at: 0, value: Rectangle(x: 0, y: 0, width: 100, height: 40)),
            Keyframe(at: 1, value: Rectangle(x: 100, y: 200, width: 300, height: 20))
        ])

        // When
        let point = points.value(at: 3.5)
        let area = areas.value(at: 0.5)

        // Then
        #expect(point == Point(x: 465, y: 700))
        #expect(area == Rectangle(x: 50, y: 100, width: 200, height: 30))
    }

    @Test("a crop moves its centre in a straight line and changes its size geometrically")
    func interpolatesCropGeometrically() throws {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 0, value: Crop(Rectangle(x: 0, y: 0, width: 400, height: 200))),
            Keyframe(at: 1, value: Crop(Rectangle(x: 300, y: 150, width: 100, height: 50)))
        ])

        // When
        let crop = try #require(sut.value(at: 0.5)).rectangle

        // Then
        #expect(abs(crop.width - 200) < 1e-9)
        #expect(abs(crop.height - 100) < 1e-9)
        #expect(abs(crop.center.x - 275) < 1e-9)
        #expect(abs(crop.center.y - 137.5) < 1e-9)
    }

    @Test("two keyframes at one instant cut to the later one")
    func cutsAtSharedInstant() {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 0, value: 0.0),
            Keyframe(at: 1, value: 0.0),
            Keyframe(at: 1, value: 1.0),
            Keyframe(at: 2, value: 1.0)
        ])

        // When
        let before = sut.value(at: 0.99)
        let at = sut.value(at: 1)

        // Then
        #expect(before == 0)
        #expect(at == 1)
    }

    @Test("a track's range over a time range reads only the part of each span inside it, held past its keyframes")
    func givesRangeOverVisibleSpan() {
        // Given
        let sut = KeyframeTrack(keyframes: [Keyframe(at: 1, value: 0.0), Keyframe(at: 3, value: 100.0)])

        // When
        let inside = sut.range(over: TimeRange(start: 1.5, end: 2))
        let before = sut.range(over: TimeRange(start: 0, end: 0.5))
        let across = sut.range(over: TimeRange(start: 0, end: 9))

        // Then
        #expect(inside == 25...50)
        #expect(before == 0...0)
        #expect(across == 0...100)
    }

    @Test("a track's range takes an ease's overshoot only where it falls inside the time range")
    func givesOvershootInsideRange() {
        // Given
        let sut = KeyframeTrack(keyframes: [Keyframe(at: 0, value: 0.0, ease: .backOut), Keyframe(at: 1, value: 60.0)])
        let turn = 1 - 2 * 1.70158 / (3 * 2.70158)

        // When
        let whole = sut.range(over: TimeRange(start: 0, end: 2))
        let early = sut.range(over: TimeRange(start: 0, end: 0.5))

        // Then
        #expect(abs(whole.upperBound - 60 * Ease.backOut.value(at: turn)) < 1e-9)
        #expect(whole.upperBound > 65.9)
        #expect(abs(early.upperBound - 60 * Ease.backOut.value(at: 0.5)) < 1e-9)
    }

    @Test("an instant past a step end from T takes the value before it, so the FRAMES-29 title shows its old place and then its new one")
    func clampsStepEndFromBefore() {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 1, value: 100.0, ease: .step),
            Keyframe(at: 1.53, value: 900.0),
            Keyframe(at: 3, value: 900.0)
        ])
        let before = (0..<16).map { 1.52 + (Double($0) + 0.5) / 16 * 0.02 }
        let after = (0..<16).map { 1.56 + (Double($0) + 0.5) / 16 * 0.02 }

        // When
        let first = before.map { sut.value(at: $0, onSideOf: 1.52) }
        let next = after.map { sut.value(at: $0, onSideOf: 1.56) }
        let onTheEnd = sut.value(at: 1.53, onSideOf: 1.52)

        // Then
        #expect(first.allSatisfy { $0 == 100 })
        #expect(next.allSatisfy { $0 == 900 })
        #expect(onTheEnd == 100)
    }

    @Test("an instant before T across a step end takes the value at the end, the side T reads")
    func clampsStepEndFromAfter() {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 1, value: 100.0, ease: .step),
            Keyframe(at: 1.53, value: 900.0, ease: .linear),
            Keyframe(at: 2.53, value: 1900.0)
        ])

        // When
        let crossing = sut.value(at: 1.525, onSideOf: 1.54)
        let onTheEnd = sut.value(at: 1.52, onSideOf: 1.53)

        // Then
        #expect(crossing == 900)
        #expect(onTheEnd == 900)
    }

    @Test("two keyframes at one instant clamp an instant to T's side: the first value from before, the second from it")
    func clampsDoubleKeyframe() {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 0, value: 0.0),
            Keyframe(at: 1, value: 10.0),
            Keyframe(at: 1, value: 50.0),
            Keyframe(at: 2, value: 60.0)
        ])

        // When
        let fromBefore = sut.value(at: 1.1, onSideOf: 0.9)
        let fromAfter = sut.value(at: 0.95, onSideOf: 1.05)
        let fromOn = sut.value(at: 0.95, onSideOf: 1)
        let onwards = sut.value(at: 1.05, onSideOf: 1)

        // Then
        #expect(fromBefore == 10)
        #expect(fromAfter == 50)
        #expect(fromOn == 50)
        #expect(abs((onwards ?? 0) - 50.5) < 1e-9)
    }

    @Test("a step span that ends on two keyframes is clamped to its start value from before")
    func clampsStepIntoDoubleKeyframe() {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 0, value: 0.0, ease: .step),
            Keyframe(at: 1, value: 10.0),
            Keyframe(at: 1, value: 50.0)
        ])

        // When
        let value = sut.value(at: 1.2, onSideOf: 0.5)

        // Then
        #expect(value == 0)
    }

    @Test("without a jump between T and the instant, the instant reads the curve as it is, past the keyframes too")
    func readsWithoutJump() {
        // Given
        let sut = KeyframeTrack(keyframes: [
            Keyframe(at: 0, value: 0.0, ease: .easeInOut),
            Keyframe(at: 1, value: 10.0)
        ])

        // When
        let inside = sut.value(at: 0.7, onSideOf: 0.6)
        let past = sut.value(at: 1.2, onSideOf: 0.95)

        // Then
        #expect(inside == sut.value(at: 0.7))
        #expect(past == 10)
    }
}
