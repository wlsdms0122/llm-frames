//
//  TrackerTable.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

@testable import Frames

// A fake tracker: in each file the target can be followed on the frames whose media times lie in a range, and on
// each it has moved by `drift` per media second from where it was given, so a test tells which rectangle was given.
// Outside that range the target is lost.
struct TrackerTable: TrackerProvider {
    // MARK: - Property
    let frameTimes: [String: [Double]]
    let followed: [String: ClosedRange<Double>]
    let drift: Point

    // MARK: - Initializer
    init(
        frameTimes: [String: [Double]],
        followed: [String: ClosedRange<Double>] = [:],
        drift: Point = Point(x: 0, y: 0)
    ) {
        self.frameTimes = frameTimes
        self.followed = followed
        self.drift = drift
    }

    // MARK: - Public
    func track(
        _ target: Rectangle,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>
    ) throws -> [TrackedFrame] {
        let times = frameTimes[file.path] ?? []
        let shown = times.last { $0 <= time } ?? times.first ?? time
        let followed = followed[file.path] ?? -Double.infinity...Double.infinity
        guard followed.contains(shown) else { return [] }

        // From the frame shown at `time`, out to the first frame lost in each direction.
        let index = times.firstIndex(of: shown) ?? 0
        let after = times[index...].prefix { range.contains($0) && followed.contains($0) || $0 == shown }
        let before = times[..<index].reversed().prefix { range.contains($0) && followed.contains($0) }

        return (before.reversed() + after).map { frameTime in
            TrackedFrame(
                time: frameTime,
                rectangle: Rectangle(
                    x: target.x + drift.x * (frameTime - shown),
                    y: target.y + drift.y * (frameTime - shown),
                    width: target.width,
                    height: target.height
                )
            )
        }
    }

    // MARK: - Private
}
