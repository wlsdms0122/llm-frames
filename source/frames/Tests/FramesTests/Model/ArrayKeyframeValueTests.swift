//
//  ArrayKeyframeValueTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("Array+KeyframeValue Tests")
struct ArrayKeyframeValueTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "an opacity an overshooting ease carries past its keyframes is drawn from 0 to 1",
        arguments: [Ease.backOut, .spring(bounce: 0.6)]
    )
    func clampsOpacity(ease: Ease) {
        // Given
        let sut = [Keyframe(at: 0, value: 0.0, ease: ease), Keyframe(at: 1, value: 1.0)]
        let falling = [Keyframe(at: 0, value: 1.0, ease: ease), Keyframe(at: 1, value: 0.0)]

        // When
        let carried: Double = sut.value(at: 0.6)
        let opacity = sut.opacity(at: 0.6)
        let fallen = falling.opacity(at: 0.6)

        // Then
        #expect(carried > 1)
        #expect(opacity == 1)
        #expect(fallen == 0)
    }
}
