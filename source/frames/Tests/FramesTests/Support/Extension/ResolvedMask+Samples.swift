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

            case .path:
                Keyframe(at: sample.at, value: Rectangle(x: 0, y: 0, width: 0, height: 0))
            }
        }

        let geometry: ResolvedMaskGeometry = switch samples[0].geometry {
        case .rect:
            .rect(.area(.keyframes(rectangles.map { $0.map(GeometryArea.rectangle) })), radius: .keyframes(samples.map { sample in
                if case let .rect(_, radius) = sample.geometry {
                    Keyframe(at: sample.at, value: radius)
                } else {
                    Keyframe(at: sample.at, value: 0)
                }
            }))

        case .ellipse:
            .ellipse(.area(.keyframes(rectangles.map { $0.map(GeometryArea.rectangle) })))

        case let .path(vertices, _):
            .path(vertices.indices.map { index in
                let leaf = { (value: (PathVertex<Point, Point>) -> Point) in
                    samples.map { sample in
                        if case let .path(vertices, _) = sample.geometry {
                            Keyframe(at: sample.at, value: value(vertices[index]))
                        } else {
                            Keyframe(at: sample.at, value: Point(x: 0, y: 0))
                        }
                    }
                }
                return PathVertex(
                    vertex: .keyframes(leaf(\.vertex).map { $0.map(GeometryPoint.point) }),
                    inTangent: .keyframes(leaf(\.inTangent)),
                    outTangent: .keyframes(leaf(\.outTangent))
                )
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
