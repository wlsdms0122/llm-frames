//
//  PlaneMotion.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import FramesTestMedia

// How a poster moves before the camera over the frames of a planar tracker's video, at a focal length of 600 pixels,
// where a distance of 600 shows the poster at its own size.
enum PlaneMotion: String, Sendable {
    case translation
    case swing
    case zoomIn
    case zoomOut
    case rotation
    case nod

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The pose on frame `index` of `count`.
    func pose(
        at index: Int,
        of count: Int
    ) -> PlanePose {
        let progress = Double(index) / Double(count - 1)
        switch self {
        case .translation:
            return PlanePose(x: -150 + 300 * progress, y: -40 + 80 * progress, distance: 800)

        case .swing:
            return PlanePose(
                x: -60 + 120 * progress,
                y: 20 * sin(4 * progress),
                distance: 950 - 150 * progress,
                yaw: -35 + 70 * progress,
                pitch: 12 * sin(2 * .pi * progress)
            )

        case .zoomIn:
            return PlanePose(distance: 1200 * pow(0.4, progress), yaw: 10 * sin(3 * progress))

        case .zoomOut:
            return PlanePose(distance: 600 * pow(2.5, progress), yaw: 10 * sin(3 * progress))

        case .rotation:
            return PlanePose(distance: 800, yaw: 15, roll: 160 * progress)

        case .nod:
            return PlanePose(x: 30 * sin(5 * progress), distance: 800, yaw: -10 + 20 * progress)
        }
    }

    // MARK: - Private
}
