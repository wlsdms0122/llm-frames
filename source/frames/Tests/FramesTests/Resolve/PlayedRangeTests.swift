//
//  PlayedRangeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames
import Testing

@Suite("PlayedRange Tests")
struct PlayedRangeTests {
    // MARK: - Property
    // Ten frames a second, so `in` 0.1 is frame 1 and the frame before `out` 0.3 is frame 2.
    private let file = MediaFile(path: "/media/a.mov", frameTimes: (0..<10).map { Double($0) / 10 })

    // MARK: - Initializer
    // MARK: - Test
    // The seams are sums of the period from origin 1, where 1 + 0.2 lands a hair past 1.2 and its clip time a hair
    // under `out`.
    @Test(
        "a looping clip picks the frame at in at every seam and the frame before out just before it",
        arguments: [1.0, 2.0]
    )
    func picksFramesAtLoopSeams(speed: Double) {
        // Given
        let map = TimeMap(origin: 1, in: 0.1, speed: speed)
        let sut = PlayedRange(map: map, out: 0.3, loop: true)
        let period = 0.2 / speed
        let seams = (1...4).map { count in (0..<count).reduce(1.0) { time, _ in time + period } }

        // When
        let atSeams = seams.map { sut.clipTime(atSequenceTime: $0) }
        let beforeSeams = seams.map { sut.clipTime(atSequenceTime: $0 - period / 4) }

        // Then
        #expect(atSeams.map(file.frameIndex(at:)) == [1, 1, 1, 1])
        #expect(beforeSeams.map(file.frameIndex(at:)) == [2, 2, 2, 2])
        #expect((atSeams + beforeSeams).allSatisfy { (0.1..<0.3).contains($0) })
    }

    @Test(
        "a clip that does not loop holds the frame before out at and past out",
        arguments: [0.7 + 0.5, 1.5, 9.0]
    )
    func holdsPastOut(time: Double) {
        // Given
        let sut = PlayedRange(map: TimeMap(origin: 1, in: 0.1, speed: 1), out: 0.3, loop: false)

        // When
        let clipTime = sut.clipTime(atSequenceTime: time)

        // Then
        #expect(file.frameIndex(at: clipTime) == 2)
    }

    @Test("before out a clip plays along its line, looping or not")
    func playsBeforeOut() {
        // Given
        let map = TimeMap(origin: 1, in: 0.1, speed: 1)

        // When
        let looping = PlayedRange(map: map, out: 0.3, loop: true).clipTime(atSequenceTime: 1.15)
        let once = PlayedRange(map: map, out: 0.3, loop: false).clipTime(atSequenceTime: 1.15)

        // Then
        #expect(looping == map.clipTime(atSequenceTime: 1.15))
        #expect(once == looping)
    }

    // MARK: - Private
}
