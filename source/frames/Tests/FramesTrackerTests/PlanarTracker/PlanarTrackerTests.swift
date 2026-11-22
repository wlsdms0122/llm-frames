//
//  PlanarTrackerTests.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import FramesTracker
import Testing

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading video at once can
// all hold.
@Suite("PlanarTracker Tests", .serialized)
struct PlanarTrackerTests {
    // MARK: - Property
    private let decoder = AVFoundationDecoder()
    private let size = Size(width: 640, height: 360)
    private let focal = 600.0
    private let frameCount = 40
    private let end = 40.0 / 30
    private let posterSize = Size(width: 400, height: 280)
    // The target in the poster's pixels, 210 x 135 media pixels where the poster is seen at its own size.
    private let target = Quad(Rectangle(x: 60, y: 50, width: 280, height: 180))
    private let poster = GreyTexture.poster(width: 400, height: 280, seed: 7)
    private let background = GreyTexture.poster(width: 640, height: 360, seed: 31)

    // MARK: - Initializer
    // MARK: - Test
    @Test("the test media draws the poster where its corners are placed, to the pixel")
    func drawsPosterAtPlacement() {
        // Given
        let placed = Quad(Rectangle(x: 100, y: 40, width: 400, height: 280))
        let shifted = Quad(Rectangle(x: 105, y: 43, width: 400, height: 280))
        let sut = PlaneMovie(size: size, frameTimes: [0, 1.0 / 30], end: 2.0 / 30, poster: poster, background: background) {
            $0 == 0 ? placed : shifted
        }

        // When
        let first = sut.picture(at: 0)
        let second = sut.picture(at: 1)

        // Then
        var largest: Float = 0
        for y in 41..<319 {
            for x in 101..<499 {
                largest = max(largest, abs(first[y * 640 + x] - second[(y + 3) * 640 + x + 5]))
            }
        }
        #expect(largest == 0)
    }

    @Test(
        "a target drawn still, or moved by whole pixels, and read as drawn is followed with no error",
        arguments: [(0.0, 0.0), (4, 2)]
    )
    func followsDrawnTarget(step: (x: Double, y: Double)) throws {
        // Given
        let count = 16
        let placement = { (index: Int) in
            Quad(Rectangle(x: 120 + step.x * Double(index), y: 40 + step.y * Double(index), width: 400, height: 280))
        }
        let movie = PlaneMovie(size: size, frameTimes: [], end: 0, poster: poster, background: background, placement: placement)
        let frameTimes = (0..<count).map { Double($0) / 30 }
        let media = MediaFile(path: "drawn.mov", size: size, frameTimes: frameTimes)
        let truth = try (0..<count).map { try corners(of: target, at: placement($0)) }
        let decoder = PictureDecoder(pictures: (0..<count).map { movie.picture(at: $0) }, width: 640, height: 360)
        let sut = PlanarTracker(decoder: decoder)

        // When
        let frames = try sut.track(truth[0], in: media, atMediaTime: 0, over: 0...1, colorSpace: nil)

        // Then
        #expect(frames.map(\.time) == frameTimes)
        let errors = zip(frames, truth).map { error(of: $0.quad, from: $1) }
        #expect(errors.allSatisfy { $0 <= 0.001 }, "\(errors)")
    }

    @Test(
        "a target on a moving plane is followed in its corners, from its frame both ways",
        arguments: [
            PlaneCase(motion: .translation, start: 20, tolerance: 0.25),
            PlaneCase(motion: .swing, start: 0, tolerance: 0.25),
            PlaneCase(motion: .zoomIn, start: 0, tolerance: 0.25),
            PlaneCase(motion: .zoomOut, start: 0, tolerance: 0.45),
            PlaneCase(motion: .rotation, start: 0, tolerance: 0.25)
        ]
    )
    func followsPlane(plane: PlaneCase) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let placement = { index in plane.motion.pose(at: index, of: frameCount).corners(of: posterSize, focal: focal, on: size) }
        let media = try await video(in: directory, poster: poster, placement: placement)
        let truth = try (0..<frameCount).map { try corners(of: target, at: placement($0)) }
        let sut = PlanarTracker(decoder: decoder)

        // When
        let frames = try sut.track(
            truth[plane.start],
            in: media,
            atMediaTime: media.frameTimes[plane.start],
            over: 0...end,
            colorSpace: nil
        )

        // Then
        #expect(frames.map(\.time) == media.frameTimes)
        let errors = zip(frames, truth).map { error(of: $0.quad, from: $1) }
        for (index, error) in errors.enumerated() {
            #expect(error <= plane.tolerance, "frame \(index): corner \(error) px")
        }
    }

    @Test(
        "a bar growing over the target is held while it covers a quarter, and the target lost before it covers two fifths",
        arguments: zip([PlaneMotion.nod, .swing], [BarEdge.left, .top])
    )
    func losesCoveredTarget(motion: PlaneMotion, edge: BarEdge) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let placement = { index in motion.pose(at: index, of: frameCount).corners(of: posterSize, focal: focal, on: size) }
        let truth = try (0..<frameCount).map { try corners(of: target, at: placement($0)) }
        // The share of the target's bounds the bar covers on each frame, from `edge`.
        let cover = (0..<frameCount).map { index in max(0, Double(index - 4) * 0.02) }
        let media = try await video(in: directory, poster: poster, placement: placement) { index in
            edge.bar(covering: cover[index], of: truth[index])
        }
        let sut = PlanarTracker(decoder: decoder)

        // When
        let frames = try sut.track(truth[0], in: media, atMediaTime: 0, over: 0...end, colorSpace: nil)

        // Then
        #expect(cover[frames.count - 1] >= 0.25)
        #expect(frames.count < frameCount && cover[frames.count] <= 0.4)
        for (index, (frame, corners)) in zip(frames, truth).enumerated() {
            let error = error(of: frame.quad, from: corners)
            #expect(error <= 0.45, "frame \(index): corner \(error) px")
        }
    }

    @Test("a target of one flat grey is lost on the first frame after its own")
    func losesFlatTarget() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let screen = GreyTexture.screen(width: 400, height: 280, bezel: 30)
        let placement = { index in
            PlaneMotion.translation.pose(at: index, of: frameCount).corners(of: posterSize, focal: focal, on: size)
        }
        let media = try await video(in: directory, poster: screen, placement: placement)
        let inside = try corners(of: Quad(Rectangle(x: 40, y: 40, width: 320, height: 200)), at: placement(10))
        let sut = PlanarTracker(decoder: decoder)

        // When
        let frames = try sut.track(inside, in: media, atMediaTime: media.frameTimes[10], over: 0...end, colorSpace: nil)

        // Then
        #expect(frames.map(\.time) == [media.frameTimes[10]])
    }

    // MARK: - Private
    // A video of `frameCount` frames at 30 a second of `poster` placed at `placement(i)` over the background, under the
    // bar at `occluder(i)`.
    private func video(
        in directory: TemporaryDirectory,
        poster: GreyTexture,
        placement: @escaping (Int) -> Quad,
        occluder: @escaping (Int) -> Rectangle? = { _ in nil }
    ) async throws -> MediaFile {
        let file = directory.file("plane.mov")
        let frameTimes = (0..<frameCount).map { Double($0) / 30 }
        try await PlaneMovie(
            size: size,
            frameTimes: frameTimes,
            end: end,
            poster: poster,
            background: background,
            placement: placement,
            occluder: occluder
        )
        .write(to: file)
        let probed = try #require(try decoder.probedMedia(of: file))

        return MediaFile(path: file, size: probed.size, frameTimes: probed.frames)
    }

    // Where the corners of `quad`, in the poster's pixels, lie when the poster's corners lie at `placement`.
    private func corners(
        of quad: Quad,
        at placement: Quad
    ) throws -> Quad {
        let posterRectangle = Quad(Rectangle(x: 0, y: 0, width: posterSize.width, height: posterSize.height))
        let homography = try #require(Homography(from: posterRectangle, to: placement))

        return try #require(homography.apply(to: quad))
    }

    // The largest distance between corners of the same order.
    private func error(
        of found: Quad,
        from truth: Quad
    ) -> Double {
        zip(found.corners, truth.corners).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
    }
}
