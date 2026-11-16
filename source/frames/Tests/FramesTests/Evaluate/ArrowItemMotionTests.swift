//
//  ArrowItemMotionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ArrowItem+Motion Tests")
struct ArrowItemMotionTests {
    // MARK: - Property
    // 200 long, pointing right.
    private let sut = ArrowItem(
        tail: Point(x: 0, y: 100),
        head: Point(x: 200, y: 100),
        width: 6,
        headSize: 24,
        color: Color(written: "#FF0000")
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("an arrow found pointing at an area has its tip as its head")
    func takesArrowGeometry() {
        // Given
        let arrow = Arrow(pointingAt: Rectangle(x: 100, y: 100, width: 50, height: 50), from: .left, length: 80, breadth: 24)

        // When
        let item = ArrowItem(arrow: arrow, width: 6, headSize: 24, color: Color(written: "#FF0000"))

        // Then
        #expect(item.tail == Point(x: 20, y: 125))
        #expect(item.head == Point(x: 100, y: 125))
    }

    @Test("reveal grows the arrow from its tail to its head")
    func revealGrowsFromTail() {
        // Given
        let motion = Motion(values: [.reveal: 0.5])

        // When
        let moved = sut.moved(by: motion)

        // Then
        #expect(moved.tail == Point(x: 0, y: 100))
        #expect(moved.head == Point(x: 100, y: 100))
        #expect(moved.width == 6)
        #expect(moved.headSize == 24)
    }

    @Test("nudge moves the arrow towards what it points at by multiples of its length")
    func nudgeMovesTowardsTarget() {
        // Given
        let motion = Motion(values: [.nudge: 0.25])

        // When
        let moved = sut.moved(by: motion)

        // Then
        #expect(moved.tail == Point(x: 50, y: 100))
        #expect(moved.head == Point(x: 250, y: 100))
    }

    @Test("a nudge measures the arrow's whole length before the reveal shortens it")
    func nudgeMeasuresWholeArrow() {
        // Given
        let motion = Motion(values: [.nudge: 0.25, .reveal: 0.5])

        // When
        let moved = sut.moved(by: motion)

        // Then
        #expect(moved.tail == Point(x: 50, y: 100))
        #expect(moved.head == Point(x: 150, y: 100))
    }
}
