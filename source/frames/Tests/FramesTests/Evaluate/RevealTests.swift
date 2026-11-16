//
//  RevealTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("Reveal Tests")
struct RevealTests {
    // MARK: - Property
    private let rectangle = Rectangle(x: 10, y: 20, width: 100, height: 50)

    // MARK: - Initializer
    // MARK: - Test
    @Test("an amount past either end is held at it", arguments: [(1.2, 1.0), (-0.1, 0.0), (0.3, 0.3)])
    func holdsAmount(written: Double, amount: Double) {
        // Given, When
        let sut = Reveal(amount: written, edge: .left)

        // Then
        #expect(sut.amount == amount)
    }

    @Test("a wipe shows the rectangle from its side", arguments: [
        (RevealEdge.left, Rectangle(x: 10, y: 20, width: 40, height: 50)),
        (RevealEdge.right, Rectangle(x: 70, y: 20, width: 40, height: 50)),
        (RevealEdge.top, Rectangle(x: 10, y: 20, width: 100, height: 20)),
        (RevealEdge.bottom, Rectangle(x: 10, y: 50, width: 100, height: 20))
    ])
    func wipesFromSide(edge: RevealEdge, shown: Rectangle) {
        // Given
        let sut = Reveal(amount: 0.4, edge: edge)

        // When
        let wiped = sut.rectangle(wiping: rectangle)

        // Then
        #expect(wiped == shown)
    }

    @Test("a wipe that shows everything gives no rectangle, and one that shows nothing an empty one")
    func wipesEnds() {
        // Given
        let whole = Reveal.full
        let none = Reveal(amount: 0, edge: .left)

        // When
        let wholeWiped = whole.rectangle(wiping: rectangle)
        let noneWiped = none.rectangle(wiping: rectangle)

        // Then
        #expect(wholeWiped == nil)
        #expect(noneWiped == Rectangle(x: 10, y: 20, width: 0, height: 50))
    }

    @Test("a dim's hole closes in from all it darkens to the area", arguments: [
        (0.0, Rectangle(x: 0, y: 0, width: 1000, height: 1000)),
        (0.5, Rectangle(x: 200, y: 150, width: 600, height: 550)),
        (1.0, Rectangle(x: 400, y: 300, width: 200, height: 100))
    ])
    func closesHole(amount: Double, hole: Rectangle) {
        // Given
        let sut = Reveal(amount: amount, edge: .left)

        // When
        let closing = sut.hole(
            closingFrom: Rectangle(x: 0, y: 0, width: 1000, height: 1000),
            to: Rectangle(x: 400, y: 300, width: 200, height: 100)
        )

        // Then
        #expect(closing == hole)
    }

    @Test("a box's stroke is trimmed to the amount shown")
    func trimsStroke() {
        // Given
        let sut = MotionSample(motion: Motion(values: [.reveal: 0.75]), revealFrom: .left)

        // When
        let trim = sut.reveal.amount

        // Then
        #expect(trim == 0.75)
    }
}
