//
//  RectangleVisionBoxTests.swift
//  FramesVisionTests
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Frames
import Testing

@testable import FramesVision

@Suite("Rectangle+VisionBox Tests")
struct RectangleVisionBoxTests {
    // MARK: - Property
    private let size = Size(width: 200, height: 100)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a Vision box from the bottom left becomes a rectangle in pixels from the top left")
    func readsVisionBox() {
        // Given
        let box = CGRect(x: 0.25, y: 0.125, width: 0.5, height: 0.5)

        // When
        let sut = Rectangle(visionBox: box, in: size)

        // Then
        #expect(sut == Rectangle(x: 50, y: 37.5, width: 100, height: 50))
    }

    @Test("a rectangle in pixels from the top left becomes a Vision box from the bottom left")
    func writesVisionBox() {
        // Given
        let sut = Rectangle(x: 50, y: 37.5, width: 100, height: 50)

        // When
        let box = sut.visionBox(in: size)

        // Then
        #expect(box == CGRect(x: 0.25, y: 0.125, width: 0.5, height: 0.5))
    }
}
