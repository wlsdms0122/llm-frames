//
//  ResolvedMask+Samples.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A mask whose every number is keyed at the same times, given by its geometry and feather at each, all of one form as
// the first's: one sample for a mask no keyframe moves.
extension ResolvedMask {
    // MARK: - Property
    // MARK: - Initializer
    init(
        geometry: PathGeometry,
        feather: Double,
        isInverted: Bool,
        mode: MaskMode,
        at time: Double = 0
    ) {
        self.init(samples: [(time, geometry, feather)], isInverted: isInverted, mode: mode)
    }

    init(
        samples: [(at: Double, geometry: PathGeometry, feather: Double)],
        isInverted: Bool = false,
        mode: MaskMode = .add
    ) {
        let rectangles = samples.map { sample in
            switch sample.geometry {
            case let .rect(rectangle, _), let .ellipse(rectangle):
                Keyframe(at: sample.at, value: rectangle)

            case .polyline:
                Keyframe(at: sample.at, value: Rectangle(x: 0, y: 0, width: 0, height: 0))
            }
        }

        let geometry: ResolvedMaskGeometry = switch samples[0].geometry {
        case .rect:
            .rect(.area(rectangles.map { $0.map(GeometryArea.rectangle) }), radius: samples.map { sample in
                if case let .rect(_, radius) = sample.geometry {
                    Keyframe(at: sample.at, value: radius)
                } else {
                    Keyframe(at: sample.at, value: 0)
                }
            })

        case .ellipse:
            .ellipse(.area(rectangles.map { $0.map(GeometryArea.rectangle) }))

        case let .polyline(points, _):
            .polyline(points.indices.map { index in
                samples.map { sample in
                    if case let .polyline(points, _) = sample.geometry {
                        Keyframe(at: sample.at, value: GeometryPoint.point(points[index]))
                    } else {
                        Keyframe(at: sample.at, value: GeometryPoint.point(Point(x: 0, y: 0)))
                    }
                }
            })
        }

        self.init(
            geometry: geometry,
            feather: samples.map { Keyframe(at: $0.at, value: $0.feather) },
            isInverted: isInverted,
            mode: mode
        )
    }

    // MARK: - Public
    // MARK: - Private
}
