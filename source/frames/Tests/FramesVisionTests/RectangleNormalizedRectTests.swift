//
//  RectangleNormalizedRectTests.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Frames
import Testing

@testable import FramesVision

@Suite("Rectangle+NormalizedRect Tests")
struct RectangleNormalizedRectTests {
    // MARK: - Property
    private let size = Size(width: 200, height: 100)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a normalized rect from the bottom left becomes a rectangle in pixels from the top left")
    func readsNormalizedRect() {
        // Given
        let rect = CGRect(x: 0.25, y: 0.125, width: 0.5, height: 0.5)

        // When
        let sut = Rectangle(normalizedRect: rect, in: size)

        // Then
        #expect(sut == Rectangle(x: 50, y: 37.5, width: 100, height: 50))
    }

    @Test("a rectangle in pixels from the top left becomes a normalized rect from the bottom left")
    func writesNormalizedRect() {
        // Given
        let sut = Rectangle(x: 50, y: 37.5, width: 100, height: 50)

        // When
        let rect = sut.normalizedRect(in: size)

        // Then
        #expect(rect == CGRect(x: 0.25, y: 0.125, width: 0.5, height: 0.5))
    }
}
