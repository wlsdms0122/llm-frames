//
//  BitDepthTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Frames
import Testing

@Suite("BitDepth Tests")
struct BitDepthTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "media components are held at eight bits up to eight, and at sixteen above",
        arguments: [
            (8, BitDepth.eight),
            (10, BitDepth.sixteen),
            (16, BitDepth.sixteen)
        ]
    )
    func holdsMediaDepth(
        bitsPerComponent: Int,
        expected: BitDepth
    ) {
        // Given
        let media = bitsPerComponent

        // When
        let sut = BitDepth(holding: media)

        // Then
        #expect(sut == expected)
        #expect(sut.bitsPerComponent >= media)
    }
}
