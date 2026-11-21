//
//  TargetFollowerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// The fake tracker grows what it is given by half its size per media second about that quad's centroid, so where a
// followed quad lands tells which quad the tracker was given. `QuadTrackerTable` reports the quads a test names.
@Suite("TargetFollower Tests")
struct TargetFollowerTests {
    // MARK: - Property
    private let file = MediaFile(path: "/abs/screen.mp4", size: Size(width: 1206, height: 2622), frameTimes: [0, 1])
    private let sut = TargetFollower(tracker: TrackerTable(frameTimes: ["/abs/screen.mp4": [0, 1]], growth: 0.5))
    private let sixFrames = MediaFile(path: "/abs/screen.mp4", size: Size(width: 1206, height: 2622), frameTimes: [0, 1, 2, 3, 4, 5])

    // MARK: - Initializer
    // MARK: - Test
    @Test("a target inside the picture is given to the tracker as it is")
    func followsTargetInside() throws {
        // Given
        let target = Rectangle(x: 100, y: 100, width: 200, height: 40)

        // When
        let frames = try sut.follow(Quad(target), in: file, atMediaTime: 0, over: 0...1, colorSpace: nil)

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
        let frames = try sut.follow(Quad(target), in: file, atMediaTime: 0, over: 0...1, colorSpace: nil)

        // Then
        let expected = Quad(target).applying(AffineTransform(scale: 1.5, about: Quad(inside).centroid))
        #expect(frames.map(\.time) == [0, 1])
        #expect(isClose(frames[0].quad, Quad(target)))
        #expect(isClose(frames[1].quad, expected), "\(frames[1].quad)")
    }

    @Test("a target wholly outside the picture is followed on no frame")
    func followsNothingOutside() throws {
        // When
        let frames = try sut.follow(Quad(Rectangle(x: 1300, y: 100, width: 100, height: 40)), in: file, atMediaTime: 0, over: 0...1, colorSpace: nil)

        // Then
        #expect(frames.isEmpty)
    }

    @Test("a target partly outside is carried from the reported quad to the whole target by the homography between them")
    func carriesPartInsideByHomography() throws {
        // Given
        // The target reaches past the right edge at 1206, so the tracker is given its part inside, [1006, 100] to
        // [1206, 140], and reports that part under the perspective that takes the whole target to `far`.
        let target = Quad(Rectangle(x: 1006, y: 100, width: 400, height: 40))
        let far = Quad(
            topLeft: Point(x: 1000, y: 110),
            topRight: Point(x: 1300, y: 120),
            bottomRight: Point(x: 1320, y: 150),
            bottomLeft: Point(x: 990, y: 145)
        )
        let sut = TargetFollower(tracker: QuadTrackerTable(base: target, quads: [(0, target), (1, far)]))

        // When
        let frames = try sut.follow(target, in: file, atMediaTime: 0, over: 0...1, colorSpace: nil)

        // Then
        #expect(frames.map(\.time) == [0, 1])
        #expect(isClose(frames[0].quad, target))
        #expect(isClose(frames[1].quad, far), "\(frames[1].quad)")
    }

    @Test("a frame whose carried quad is not strictly convex is not followed, and the track ends before it in each direction")
    func endsBeforeFoldedQuad() throws {
        // Given
        let target = Quad(Rectangle(x: 100, y: 100, width: 200, height: 40))
        let folded = Quad(topLeft: target.topLeft, topRight: target.topRight, bottomRight: Point(x: 200, y: 100), bottomLeft: target.bottomLeft)
        let quads = [(0.0, folded), (1, target), (2, target), (3, target), (4, folded), (5, target)]
        let sut = TargetFollower(tracker: QuadTrackerTable(base: target, quads: quads))

        // When
        let frames = try sut.follow(target, in: sixFrames, atMediaTime: 2, over: 0...5, colorSpace: nil)

        // Then
        #expect(frames.map(\.time) == [1, 2, 3])
    }

    @Test("a frame whose carried quad runs the other way round than the target is not followed")
    func endsBeforeTurnedOverQuad() throws {
        // Given
        let target = Quad(Rectangle(x: 100, y: 100, width: 200, height: 40))
        let mirrored = Quad(topLeft: target.bottomLeft, topRight: target.bottomRight, bottomRight: target.topRight, bottomLeft: target.topLeft)
        let quads = [(0.0, target), (1, target), (2, mirrored), (3, target)]
        let sut = TargetFollower(tracker: QuadTrackerTable(base: target, quads: quads))

        // When
        let frames = try sut.follow(target, in: sixFrames, atMediaTime: 0, over: 0...3, colorSpace: nil)

        // Then
        #expect(frames.map(\.time) == [0, 1])
    }

    @Test("a target whose quad on the track's frame is lost is followed on no frame")
    func followsNothingFromLostFrame() throws {
        // Given
        let target = Quad(Rectangle(x: 100, y: 100, width: 200, height: 40))
        let mirrored = Quad(topLeft: target.bottomLeft, topRight: target.bottomRight, bottomRight: target.topRight, bottomLeft: target.topLeft)
        let sut = TargetFollower(tracker: QuadTrackerTable(base: target, quads: [(0, target), (1, mirrored), (2, target)]))

        // When
        let frames = try sut.follow(target, in: sixFrames, atMediaTime: 1, over: 0...2, colorSpace: nil)

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
