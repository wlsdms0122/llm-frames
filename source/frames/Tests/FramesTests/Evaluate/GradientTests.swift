//
//  GradientTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

@Suite("Gradient Tests")
struct GradientTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a linear position is the projection onto the line from `from` to `to` in lengths of that line")
    func positionsAlongLine() {
        // Given
        let sut = gradient(.linear(from: Point(x: 10, y: 20), to: Point(x: 110, y: 20)))

        // When
        let positions = [Point(x: 60, y: 90), Point(x: 10, y: 0), Point(x: -90, y: 20), Point(x: 160, y: 20)].map(sut.position)

        // Then
        #expect(positions == [0.5, 0, -1, 1.5])
    }

    @Test("a radial position is the distance from the centre in radii")
    func positionsOutFromCenter() {
        // Given
        let sut = gradient(.radial(center: Point(x: 10, y: 10), radius: 10))

        // When
        let positions = [Point(x: 10, y: 10), Point(x: 16, y: 18), Point(x: 10, y: 30)].map(sut.position)

        // Then
        #expect(positions == [0, 1, 2])
    }

    @Test(
        "a linear gradient whose ends are one point, or a radial one of radius 0, is degenerate and has no position",
        arguments: [
            GradientShape.linear(from: Point(x: 5, y: 5), to: Point(x: 5, y: 5)),
            GradientShape.radial(center: Point(x: 5, y: 5), radius: 0)
        ]
    )
    func isDegenerate(shape: GradientShape) {
        // Given
        let sut = gradient(shape)

        // When, Then
        #expect(sut.isDegenerate)
        #expect(sut.position(of: Point(x: 0, y: 0)) == nil)
    }

    @Test("the first stop's colour is held at and below its offset, and the last stop's at and past its offset")
    func holdsEndColors() {
        // Given
        let sut = gradient(stops: [(0.2, "#FF0000"), (0.8, "#0000FF")])

        // When, Then
        #expect(sut.channels(at: -1) == [1, 0, 0, 1])
        #expect(sut.channels(at: 0.2) == [1, 0, 0, 1])
        #expect(sut.channels(at: 0.8) == [0, 0, 1, 1])
        #expect(sut.channels(at: 3) == [0, 0, 1, 1])
    }

    @Test("between two stops the colours interpolate with premultiplied alpha at the position's place between their offsets")
    func interpolatesPremultiplied() {
        // Given
        let sut = gradient(stops: [(0, "#FF000000"), (0.5, "#0000FF")])

        // When
        let channels = sut.channels(at: 0.125)

        // Then
        // A quarter of the way: premultiplied (0, 0, 0.25, 0.25), so the transparent red adds nothing.
        expect(channels, [0, 0, 1, 0.25])
    }

    @Test("a ramp from #FFFFFF00 to black gives the same colours as one from #00000000, with no grey band")
    func addsNoColorFromTransparentStop() {
        // Given
        let white = gradient(stops: [(0, "#FFFFFF00"), (1, "#000000")])
        let black = gradient(stops: [(0, "#00000000"), (1, "#000000")])

        // When
        let positions = [0.1, 0.25, 0.5, 0.9]

        // Then
        for position in positions {
            #expect(white.channels(at: position) == black.channels(at: position), "at \(position)")
            expect(white.channels(at: position), [0, 0, 0, position])
        }
    }

    @Test("two stops at one offset make a hard edge, the later stop's colour starting there")
    func makesHardEdge() {
        // Given
        let sut = gradient(stops: [(0, "#FF0000"), (0.5, "#FF0000"), (0.5, "#0000FF"), (1, "#0000FF")])

        // When, Then
        #expect(sut.channels(at: 0.4999) == [1, 0, 0, 1])
        #expect(sut.channels(at: 0.5) == [0, 0, 1, 1])
        #expect(sut.channels(at: 0.5001) == [0, 0, 1, 1])
    }

    // MARK: - Private
    private func gradient(
        _ shape: GradientShape = .linear(from: Point(x: 0, y: 0), to: Point(x: 1, y: 0)),
        stops: [(Double, String)] = [(0, "#000000"), (1, "#FFFFFF")]
    ) -> Gradient {
        Gradient(shape: shape, stops: stops.map { offset, color in GradientStop(offset: offset, color: Color(written: color)) })
    }

    private func expect(
        _ channels: [Double],
        _ expected: [Double],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            zip(channels, expected).allSatisfy { abs($0 - $1) < 1e-9 },
            "\(channels) is not \(expected)",
            sourceLocation: sourceLocation
        )
    }
}
