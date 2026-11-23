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

    // The time of every keyframe of its geometry. A static value true on the track's frame has none.
    var geometryTimes: [Double] {
        let rectangle = { (rectangle: ResolvedMaskRectangle) -> [Double] in
            switch rectangle {
            case let .area(area):
                area.keyframeTimes

            case let .box(width, height, position):
                width.keyframeTimes + height.keyframeTimes + position.keyframeTimes
            }
        }

        return switch geometry {
        case let .rect(box, radius):
            rectangle(box) + radius.keyframeTimes

        case let .ellipse(box):
            rectangle(box)

        case let .path(vertices):
            vertices.flatMap { $0.vertex.keyframeTimes + $0.inTangent.keyframeTimes + $0.outTangent.keyframeTimes }
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
    func sampled(at time: SampleTime) -> MaskSample {
        MaskSample(
            geometry: geometry.sampled(at: time),
            feather: max(feather.value(at: time), 0),
            isInverted: isInverted,
            mode: mode
        )
    }

    // The same mask with each keyframe of its geometry carried to another space at its own time: an area, a box's
    // centre and each vertex's point by `area` and `point`, each tangent, an offset, by `tangent`, and a box's size
    // and a rect's radius by the factor `scale` gives.
    // The time is nil for a static value true on the track's frame. A clip area is in the space the clip is drawn in,
    // so it stays, and the feather is in output pixels and stays.
    func carried(
        area: (Rectangle, Double?, MaskLeaf) throws -> Rectangle,
        point: (Point, Double?, MaskLeaf) throws -> Point,
        tangent: (Point, Double?) throws -> Point,
        scale: (Double?) throws -> Double
    ) rethrows -> ResolvedMask {
        let geometry: ResolvedMaskGeometry = switch self.geometry {
        case let .rect(box, radius):
            .rect(
                try Self.carried(box, area: area, point: point, scale: scale),
                radius: try Self.carried(radius) { try $0 * scale($1) }
            )

        case let .ellipse(box):
            .ellipse(try Self.carried(box, area: area, point: point, scale: scale))

        case let .path(vertices):
            .path(try vertices.enumerated().map { index, vertex in
                PathVertex(
                    vertex: try Self.carried(vertex.vertex) { value, time in
                        try value.map { try point($0, time, .point(index)) }
                    },
                    inTangent: try Self.carried(vertex.inTangent, by: tangent),
                    outTangent: try Self.carried(vertex.outTangent, by: tangent)
                )
            })
        }

        return ResolvedMask(geometry: geometry, feather: feather, isInverted: isInverted, mode: mode)
    }

    // The same mask with each leaf of its geometry that `isOnTrackFrame` takes a static value true on the track's frame.
    func onTrackFrame(where isOnTrackFrame: (MaskLeaf) -> Bool) -> ResolvedMask {
        let geometry: ResolvedMaskGeometry = switch self.geometry {
        case let .rect(box, radius):
            .rect(Self.onTrackFrame(box, where: isOnTrackFrame), radius: Self.onTrackFrame(radius, isOnTrackFrame(.radius)))

        case let .ellipse(box):
            .ellipse(Self.onTrackFrame(box, where: isOnTrackFrame))

        case let .path(vertices):
            .path(vertices.enumerated().map { index, vertex in
                PathVertex(
                    vertex: Self.onTrackFrame(vertex.vertex, isOnTrackFrame(.point(index))),
                    inTangent: Self.onTrackFrame(vertex.inTangent, isOnTrackFrame(.inTangent(index))),
                    outTangent: Self.onTrackFrame(vertex.outTangent, isOnTrackFrame(.outTangent(index)))
                )
            })
        }

        return ResolvedMask(geometry: geometry, feather: feather, isInverted: isInverted, mode: mode)
    }

    // MARK: - Private
    private static func onTrackFrame(
        _ rectangle: ResolvedMaskRectangle,
        where isOnTrackFrame: (MaskLeaf) -> Bool
    ) -> ResolvedMaskRectangle {
        switch rectangle {
        case let .area(area):
            .area(onTrackFrame(area, isOnTrackFrame(.area)))

        case let .box(width, height, position):
            .box(
                width: onTrackFrame(width, isOnTrackFrame(.width)),
                height: onTrackFrame(height, isOnTrackFrame(.height)),
                position: onTrackFrame(position, isOnTrackFrame(.position))
            )
        }
    }

    private static func onTrackFrame<Value>(
        _ value: FollowedValue<Value>,
        _ isOnTrackFrame: Bool
    ) -> FollowedValue<Value> {
        guard isOnTrackFrame, case let .keyframes(keyframes) = value, keyframes.count == 1 else { return value }

        return .onTrackFrame(keyframes[0].value)
    }

    private static func carried(
        _ rectangle: ResolvedMaskRectangle,
        area: (Rectangle, Double?, MaskLeaf) throws -> Rectangle,
        point: (Point, Double?, MaskLeaf) throws -> Point,
        scale: (Double?) throws -> Double
    ) rethrows -> ResolvedMaskRectangle {
        switch rectangle {
        case let .area(keyframes):
            .area(try carried(keyframes) { value, time in try value.map { try area($0, time, .area) } })

        case let .box(width, height, position):
            .box(
                width: try carried(width) { try $0 * scale($1) },
                height: try carried(height) { try $0 * scale($1) },
                position: try carried(position) { value, time in try value.map { try point($0, time, .position) } }
            )
        }
    }

    private static func carried<Value>(
        _ value: FollowedValue<Value>,
        by carry: (Value, Double?) throws -> Value
    ) rethrows -> FollowedValue<Value> {
        try value.carried(keyframe: { try carry($0, $1) }, onTrackFrame: { try carry($0, nil) })
    }
}
