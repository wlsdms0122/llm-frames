//
//  TrackTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// The target moves 10 pixels down on each frame of a 30 fps video followed over [1.7, 1.9].
@Suite("Track Tests")
struct TrackTests {
    // MARK: - Property
    private let target = Quad(Rectangle(x: 100, y: 100, width: 200, height: 40))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a media time one floating point step under a frame's timestamp takes that frame's motion")
    func picksFrameToTheMicrosecond() {
        // Given
        let sut = track()

        // When
        let motion = sut.motion(atMediaTime: 0 + 6 * 0.3)

        // Then
        #expect(0 + 6 * 0.3 < 1.8)
        #expect(motion == sut.motion(atMediaTime: 1.8))
        #expect(motion != sut.motion(atMediaTime: 1.8 - 1.0 / 30))
    }

    @Test("a media time between two frames takes the motion of the earlier one")
    func holdsEarlierFrame() {
        // Given
        let sut = track()

        // When
        let motion = sut.motion(atMediaTime: 1.81)

        // Then
        #expect(motion == sut.motion(atMediaTime: 1.8))
    }

    // MARK: - Private
    private func track() -> Track {
        Track(
            target: target,
            mediaTime: 1.7,
            samples: (51...57).map { frame in
                let moved = Quad(Rectangle(x: 100, y: 100 + Double(frame - 51) * 10, width: 200, height: 40))

                return TrackSample(
                    time: Double(frame) / 30,
                    quad: moved,
                    motion: TrackMotion(from: target, to: moved)
                )
            }
        )
    }
}
