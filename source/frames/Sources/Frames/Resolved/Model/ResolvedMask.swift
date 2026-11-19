//
//  ResolvedMask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// One mask of a clip: its geometry in the clip's own coordinate space and its feather in output pixels, each number
// a keyframe list in sequence time, and whether it is inverted and how it combines with the masks before it, which
// are static.
struct ResolvedMask: Equatable, Sendable {
    // MARK: - Property
    let geometry: ResolvedMaskGeometry
    let feather: [Keyframe<Double>]
    let isInverted: Bool
    let mode: MaskMode

    // The time of every keyframe of its geometry.
    var geometryTimes: [Double] {
        let rectangle = { (rectangle: ResolvedMaskRectangle) -> [Double] in
            switch rectangle {
            case let .area(area):
                area.map(\.at)

            case let .box(width, height, position):
                (width.map(\.at) + height.map(\.at) + position.map(\.at))
            }
        }

        return switch geometry {
        case let .rect(box, radius):
            rectangle(box) + radius.map(\.at)

        case let .ellipse(box):
            rectangle(box)

        case let .polyline(points):
            points.flatMap { $0.map(\.at) }
        }
    }

    // MARK: - Initializer
    init(
        geometry: ResolvedMaskGeometry,
        feather: [Keyframe<Double>],
        isInverted: Bool,
        mode: MaskMode
    ) {
        self.geometry = geometry
        self.feather = feather
        self.isInverted = isInverted
        self.mode = mode
    }

    // MARK: - Public
    // A feather sampled below 0 by an ease that overshoots is 0.
    func sampled(at time: Double) -> MaskSample {
        MaskSample(
            geometry: geometry.sampled(at: time),
            feather: max(feather.value(at: time), 0),
            isInverted: isInverted,
            mode: mode
        )
    }

    // The same mask with each keyframe of its geometry carried to another space at its own time: an area, a box's
    // centre and each point by `area` and `point`, and a box's size and a rect's radius by the factor `scale` gives.
    // The feather is in output pixels and stays.
    func carried(
        area: (Rectangle, Double, MaskLeaf) -> Rectangle,
        point: (Point, Double, MaskLeaf) -> Point,
        scale: (Double) -> Double
    ) -> ResolvedMask {
        func rectangle(_ rectangle: ResolvedMaskRectangle) -> ResolvedMaskRectangle {
            switch rectangle {
            case let .area(keyframes):
                .area(carried(keyframes) { area($0, $1, .area) })

            case let .box(width, height, position):
                .box(
                    width: carried(width) { $0 * scale($1) },
                    height: carried(height) { $0 * scale($1) },
                    position: carried(position) { point($0, $1, .position) }
                )
            }
        }

        let geometry: ResolvedMaskGeometry = switch self.geometry {
        case let .rect(box, radius):
            .rect(rectangle(box), radius: carried(radius) { $0 * scale($1) })

        case let .ellipse(box):
            .ellipse(rectangle(box))

        case let .polyline(points):
            .polyline(points.enumerated().map { index, keyframes in
                carried(keyframes) { point($0, $1, .point(index)) }
            })
        }

        return ResolvedMask(geometry: geometry, feather: feather, isInverted: isInverted, mode: mode)
    }

    // MARK: - Private
    private func carried<Value: Interpolable>(
        _ keyframes: [Keyframe<Value>],
        by carry: (Value, Double) -> Value
    ) -> [Keyframe<Value>] {
        keyframes.map { Keyframe(at: $0.at, value: carry($0.value, $0.at), ease: $0.ease) }
    }
}
