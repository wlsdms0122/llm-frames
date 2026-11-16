//
//  ItemPresentationTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ItemPresentation Tests")
struct ItemPresentationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a clip's keyframes and animation combine about its anchor point: scale and opacity multiply, rotation adds")
    func combinesAboutAnchor() {
        // Given
        let values = KeyframedValues(position: Point(x: 300, y: 400), scale: 1, rotation: 60, opacity: 0.5)
        let motion = Motion(values: [.scale: 2, .rotation: 30, .opacity: 0.5, .x: 0.5])

        // When
        let sut = ItemPresentation(
            box: Size(width: 200, height: 100),
            anchor: Point(x: 100, y: 50),
            values: values,
            motion: motion
        )

        // Then
        // The top left lies (-100, -50) from the anchor, doubled to (-200, -100), turned a quarter clockwise to
        // (100, -200), then put about the anchor point (400, 450) moved 0.5 box widths right.
        expectClose(sut.transform.apply(to: Point(x: 0, y: 0)), Point(x: 600, y: 250))
        expectClose(sut.transform.apply(to: Point(x: 100, y: 50)), Point(x: 500, y: 450))
        #expect(sut.opacity == 0.25)
    }

    @Test("an offset is in multiples of the box before any scale")
    func offsetsByUnscaledBox() {
        // Given
        let values = KeyframedValues(position: Point(x: 0, y: 0))
        let motion = Motion(values: [.scale: 3, .x: 1, .y: -1])

        // When
        let sut = ItemPresentation(
            box: Size(width: 200, height: 100),
            anchor: Point(x: 0, y: 0),
            values: values,
            motion: motion
        )

        // Then
        #expect(sut.transform.apply(to: Point(x: 0, y: 0)) == Point(x: 200, y: -100))
        #expect(sut.transform.apply(to: Point(x: 10, y: 10)) == Point(x: 230, y: -70))
    }

    @Test("a still clip with a box is moved to its position and nothing else")
    func stillClipTranslates() {
        // Given
        let values = KeyframedValues(position: Point(x: 75, y: 1709))

        // When
        let sut = ItemPresentation(
            box: Size(width: 929, height: 68),
            anchor: Point(x: 464.5, y: 68),
            values: values,
            motion: Motion()
        )

        // Then
        #expect(sut.transform == AffineTransform(translation: Point(x: 75, y: 1709)))
        #expect(sut.opacity == 1)
    }

    @Test("a clip placed by an area scales and turns about the centre of its area and offsets by its size")
    func placedByAreaActsAboutCenter() {
        // Given
        let area = Rectangle(x: 100, y: 200, width: 40, height: 20)
        let motion = Motion(values: [.scale: 2, .y: 1, .opacity: 0.5])

        // When
        let sut = ItemPresentation(area: area, opacity: 0.8, motion: motion)

        // Then
        // The top left lies (-20, -10) from the centre (120, 210), doubled to (-40, -20), then moved one height down.
        #expect(sut.transform.apply(to: Point(x: 100, y: 200)) == Point(x: 80, y: 210))
        #expect(sut.transform.apply(to: Point(x: 120, y: 210)) == Point(x: 120, y: 230))
        #expect(sut.opacity == 0.4)
    }

    // MARK: - Private
    private func expectClose(
        _ point: Point,
        _ expected: Point
    ) {
        #expect(abs(point.x - expected.x) < 1e-9)
        #expect(abs(point.y - expected.y) < 1e-9)
    }
}
