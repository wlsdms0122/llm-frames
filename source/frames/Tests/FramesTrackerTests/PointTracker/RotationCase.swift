//
//  RotationCase.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames
import Testing

// A turning video for the point tracker: the scene turns `degreesPerFrame` clockwise each frame and grows geometrically from
// 1 to `growth` over its frames, both about one point, and the tracker's corners and turn may be off by the
// tolerances, in media pixels and degrees.
struct RotationCase: Sendable, CustomTestStringConvertible {
    // MARK: - Property
    let scene: TurningScene
    let degreesPerFrame: Double
    let frameCount: Int
    let growth: Double
    let cornerTolerance: Double
    let angleTolerance: Double

    var testDescription: String {
        "\(scene) at \(degreesPerFrame) degrees a frame, growing to \(growth)"
    }

    // MARK: - Initializer
    init(
        scene: TurningScene,
        degreesPerFrame: Double,
        frameCount: Int,
        growth: Double,
        cornerTolerance: Double,
        angleTolerance: Double
    ) {
        self.scene = scene
        self.degreesPerFrame = degreesPerFrame
        self.frameCount = frameCount
        self.growth = growth
        self.cornerTolerance = cornerTolerance
        self.angleTolerance = angleTolerance
    }

    // MARK: - Public
    func angle(at index: Int) -> Double {
        degreesPerFrame * Double(index)
    }

    func scale(at index: Int) -> Double {
        pow(growth, Double(index) / Double(max(frameCount - 1, 1)))
    }

    // The turn and scale of frame `index` about `centre`, clockwise positive in y-down pixels.
    func similarity(
        at index: Int,
        about centre: Point
    ) -> Frames.AffineTransform {
        let radians = angle(at: index) * .pi / 180
        let a = scale(at: index) * cos(radians)
        let b = scale(at: index) * sin(radians)

        return Frames.AffineTransform(
            a: a,
            b: b,
            c: -b,
            d: a,
            tx: centre.x - a * centre.x + b * centre.y,
            ty: centre.y - b * centre.x - a * centre.y
        )
    }

    // MARK: - Private
}
