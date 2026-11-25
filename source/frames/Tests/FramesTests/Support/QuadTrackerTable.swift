//
//  QuadTrackerTable.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

@testable import Frames

// A fake perspective tracker: on each frame of `quads` the quad `base` lies at that frame's quad, and the tracker reports
// for what it is given the image of it under H(base → that quad), or that quad itself where it is given `base`, so a
// quad that is not strictly convex can be reported. Every frame in `quads` within the range is reported.
struct QuadTrackerTable: TrackerProvider {
    // MARK: - Property
    let base: Quad
    let quads: [(time: Double, quad: Quad)]

    // MARK: - Initializer
    init(
        base: Quad,
        quads: [(time: Double, quad: Quad)]
    ) {
        self.base = base
        self.quads = quads
    }

    // MARK: - Public
    func track(
        _ target: Quad,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>,
        colorSpace: ColorSpace?
    ) throws -> [TrackedFrame] {
        quads.filter { range.contains($0.time) }.compactMap { frame in
            guard target != base else { return TrackedFrame(time: frame.time, quad: frame.quad) }

            return Homography(from: base, to: frame.quad)?.apply(to: target).map { TrackedFrame(time: frame.time, quad: $0) }
        }
    }

    // The track data a document writes for `base` followed on every frame of `quads`, whose `time` it names.
    func data(atMediaTime time: Double) -> String {
        quads.map { TrackedFrame(time: $0.time, quad: $0.quad) }.trackData(time: time)
    }

    // MARK: - Private
}
