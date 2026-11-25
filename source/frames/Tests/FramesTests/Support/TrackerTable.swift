//
//  TrackerTable.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

@testable import Frames

// A fake tracker: in each file the target can be followed on the frames whose media times lie in a range, and on
// each it has grown by `growth` of its size per media second and turned by `turn` degrees clockwise per media second
// about its centroid, and moved by `drift` per media second from where it was given, so a test tells which quad was
// given. Outside that range the target is lost.
struct TrackerTable: TrackerProvider {
    // MARK: - Property
    let frameTimes: [String: [Double]]
    let followed: [String: ClosedRange<Double>]
    let drift: Point
    let growth: Double
    let turn: Double

    // MARK: - Initializer
    init(
        frameTimes: [String: [Double]],
        followed: [String: ClosedRange<Double>] = [:],
        drift: Point = Point(x: 0, y: 0),
        growth: Double = 0,
        turn: Double = 0
    ) {
        self.frameTimes = frameTimes
        self.followed = followed
        self.drift = drift
        self.growth = growth
        self.turn = turn
    }

    // MARK: - Public
    func track(
        _ target: Quad,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>,
        colorSpace: ColorSpace?
    ) throws -> [TrackedFrame] {
        frames(of: target, in: file.path, atMediaTime: time, over: range)
    }

    // The track data a document writes for what this tracker follows from the frame at `time`, whose `time` it names.
    func data(
        _ target: Quad,
        in path: String,
        atMediaTime time: Double,
        over range: ClosedRange<Double> = -Double.infinity...Double.infinity
    ) -> String {
        frames(of: target, in: path, atMediaTime: time, over: range).trackData(time: time)
    }

    // MARK: - Private
    private func frames(
        of target: Quad,
        in path: String,
        atMediaTime time: Double,
        over range: ClosedRange<Double>
    ) -> [TrackedFrame] {
        let times = frameTimes[path] ?? []
        let shown = times.last { $0 <= time } ?? times.first ?? time
        let followed = followed[path] ?? -Double.infinity...Double.infinity
        guard followed.contains(shown) else { return [] }

        // From the frame shown at `time`, out to the first frame lost in each direction.
        let index = times.firstIndex(of: shown) ?? 0
        let after = times[index...].prefix { range.contains($0) && followed.contains($0) || $0 == shown }
        let before = times[..<index].reversed().prefix { range.contains($0) && followed.contains($0) }

        let centroid = target.centroid
        return (before.reversed() + after).map { frameTime in
            let elapsed = frameTime - shown
            let motion = AffineTransform(scale: 1 + growth * elapsed, about: centroid)
                .concatenating(AffineTransform(rotation: turn * elapsed, about: centroid))
                .concatenating(AffineTransform(translation: Point(x: drift.x * elapsed, y: drift.y * elapsed)))

            return TrackedFrame(time: frameTime, quad: target.applying(motion))
        }
    }
}
