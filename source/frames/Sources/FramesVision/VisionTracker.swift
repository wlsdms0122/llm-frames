//
//  VisionTracker.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Foundation
import Frames
import Vision

// The `vision` tracker: Vision's accurate object tracker, run from the target's frame forwards and, from it again,
// backwards over the frames the decoder reads by index. The target is lost on the first frame whose confidence falls
// below `lostConfidence`, which ends that direction.
package struct VisionTracker: Sendable {
    // MARK: - Property
    package static let lostConfidence: Float = 0.5

    private let decoder: any MediaDecoder
    private let converter = ImageConverter()

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    // The target on each of `indices` in turn, out to the frame it is lost on. The tracker starts on the target's own
    // frame.
    private func follow(
        _ target: Rectangle,
        in file: MediaFile,
        from start: Int,
        over indices: [Int]
    ) throws -> [TrackedFrame] {
        let first = try image(of: file, atFrame: start)
        let size = Size(width: Double(first.width), height: Double(first.height))
        let handler = VNSequenceRequestHandler()
        let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(
            boundingBox: normalised(target, in: size)
        ))
        request.trackingLevel = .accurate
        try handler.perform([request], on: first)

        var frames: [TrackedFrame] = []
        for index in indices {
            try handler.perform([request], on: try image(of: file, atFrame: index))
            guard
                let found = request.results?.first as? VNDetectedObjectObservation,
                found.confidence >= Self.lostConfidence
            else {
                break
            }
            let rectangle = rectangle(of: found.boundingBox, in: size)
            frames.append(TrackedFrame(time: file.frameTimes[index], rectangle: rectangle))
            request.inputObservation = found
        }

        return frames
    }

    private func image(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> CGImage {
        try converter.image(of: try decoder.picture(of: file, atFrame: index), file: file.path, index: index)
    }

    // Vision's boxes are fractions of the picture from its bottom left.
    private func normalised(
        _ rectangle: Rectangle,
        in size: Size
    ) -> CGRect {
        CGRect(
            x: rectangle.x / size.width,
            y: 1 - (rectangle.y + rectangle.height) / size.height,
            width: rectangle.width / size.width,
            height: rectangle.height / size.height
        )
    }

    private func rectangle(
        of box: CGRect,
        in size: Size
    ) -> Rectangle {
        Rectangle(
            x: box.minX * size.width,
            y: (1 - box.maxY) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }
}

extension VisionTracker: TrackerProvider {
    // MARK: - Lifecycle
    package func track(
        _ target: Rectangle,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>
    ) throws -> [TrackedFrame] {
        let start = file.frameIndex(at: time)
        let times = file.frameTimes
        guard times.indices.contains(start) else { return [] }
        let after = times.indices.filter { $0 > start && range.contains(times[$0]) }
        let before = times.indices.filter { $0 < start && range.contains(times[$0]) }.reversed()

        let forward = try follow(target, in: file, from: start, over: after)
        let backward = try follow(target, in: file, from: start, over: Array(before))

        return backward.reversed() + [TrackedFrame(time: times[start], rectangle: target)] + forward
    }
}
