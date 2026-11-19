//
//  TargetFollowerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// The fake tracker grows what it is given by half its size per media second about that quad's centroid, so where a
// followed quad lands tells which quad the tracker was given.
@Suite("TargetFollower Tests")
struct TargetFollowerTests {
    // MARK: - Property
    private let file = MediaFile(path: "/abs/screen.mp4", size: Size(width: 1206, height: 2622), frameTimes: [0, 1])
    private let sut = TargetFollower(tracker: TrackerTable(frameTimes: ["/abs/screen.mp4": [0, 1]], growth: 0.5))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a target inside the picture is given to the tracker as it is")
    func followsTargetInside() throws {
        // Given
        let target = Rectangle(x: 100, y: 100, width: 200, height: 40)

        // When
        let frames = try sut.follow(target, in: file, atMediaTime: 0, over: 0...1, colorSpace: nil)

        // Then
        #expect(frames.map(\.quad) == [
            Quad(target),
            Quad(target).applying(AffineTransform(scale: 1.5, about: Quad(target).centroid))
        ])
    }

    @Test("a target partly outside gives the tracker its part inside, and the quads come back carried to the whole target")
    func followsPartInside() throws {
        // Given
        let target = Rectangle(x: 1006, y: 100, width: 400, height: 40)
        let inside = Rectangle(x: 1006, y: 100, width: 200, height: 40)

        // When
        let frames = try sut.follow(target, in: file, atMediaTime: 0, over: 0...1, colorSpace: nil)

        // Then
        let expected = Quad(target).applying(AffineTransform(scale: 1.5, about: Quad(inside).centroid))
        #expect(frames.map(\.time) == [0, 1])
        #expect(isClose(frames[0].quad, Quad(target)))
        #expect(isClose(frames[1].quad, expected), "\(frames[1].quad)")
    }

    @Test("a target wholly outside the picture is followed on no frame")
    func followsNothingOutside() throws {
        // When
        let frames = try sut.follow(Rectangle(x: 1300, y: 100, width: 100, height: 40), in: file, atMediaTime: 0, over: 0...1, colorSpace: nil)

        // Then
        #expect(frames.isEmpty)
    }

    // MARK: - Private
    private func isClose(
        _ quad: Quad,
        _ other: Quad
    ) -> Bool {
        zip(quad.corners, other.corners).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 }
    }
}
