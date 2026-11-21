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
        let sut = Reveal(amount: written)

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
        let sut = Reveal(amount: 0.4)

        // When
        let wiped = sut.rectangle(wiping: rectangle, from: edge)

        // Then
        #expect(wiped == shown)
    }

    @Test("a wipe that shows everything gives the whole rectangle, and one that shows nothing an empty one")
    func wipesEnds() {
        // Given
        let whole = Reveal.full
        let none = Reveal(amount: 0)

        // When
        let wholeWiped = whole.rectangle(wiping: rectangle, from: .left)
        let noneWiped = none.rectangle(wiping: rectangle, from: .left)

        // Then
        #expect(wholeWiped == rectangle)
        #expect(noneWiped == Rectangle(x: 10, y: 20, width: 0, height: 50))
    }

    @Test(
        "a complete wipe from any side gives the rectangle itself, its edges not moved by rounding",
        arguments: [RevealEdge.left, .right, .top, .bottom]
    )
    func wipesWholeExactly(edge: RevealEdge) {
        // Given
        // 0.1 + 0.2 - 0.2 is 0.10000000000000003 in floating point.
        let rectangle = Rectangle(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let sut = Reveal.full

        // When
        let wiped = sut.rectangle(wiping: rectangle, from: edge)

        // Then
        #expect(wiped == rectangle)
    }

    @Test("a complete wipe writes no rectangle where no reveal is set, and the whole one where a reveal is set")
    func writesCompleteWipe() {
        // Given
        let unset = MotionSample(motion: Motion(), revealFrom: .left)
        let set = MotionSample(motion: Motion(values: [.reveal: 1]), revealFrom: .left, isRevealSet: true)

        // When
        let unsetShown = unset.revealRectangle(wiping: rectangle)
        let setShown = set.revealRectangle(wiping: rectangle)

        // Then
        #expect(unsetShown == nil)
        #expect(setShown == rectangle)
    }

    @Test("a wipe under way writes the part it shows whether or not a reveal is set", arguments: [false, true])
    func writesWipeUnderWay(isRevealSet: Bool) {
        // Given
        let sut = MotionSample(motion: Motion(values: [.reveal: 0.4]), revealFrom: .left, isRevealSet: isRevealSet)

        // When
        let shown = sut.revealRectangle(wiping: rectangle)

        // Then
        #expect(shown == Rectangle(x: 10, y: 20, width: 40, height: 50))
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
