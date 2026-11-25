//
//  GeometryFinder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Finds the areas and points of one keyframable property as resolve keeps them: a static value, and each keyframe at
// its own time, in sequence time.
struct GeometryFinder: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // `clock` is the clip's, which its keyframes are written on. A clip area is kept, its padding a theme length times
    // `lengthScale`.
    func areas(
        _ property: PropertyValue<AreaForm>,
        key: String,
        clock: TimeMap,
        lengthScale: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<AreaValue> {
        try values(property, key: key, clock: clock, place: place) { form, place in
            if let area = ClipArea(form: form, lengthScale: lengthScale) {
                return .clip(area)
            }

            return .rectangle(try form.rectangle(place: place, kind: kind))
        }
    }

    // `{scale: s}` is the centred region `1/s` the size of the picture.
    func crops(
        _ property: PropertyValue<CropForm>,
        in picture: Picture,
        clock: TimeMap,
        place: Place,
        kind: String
    ) throws -> PropertyValue<Rectangle> {
        try values(property, key: "crop", clock: clock, place: place) { form, place in
            switch form {
            case let .area(area):
                return try area.rectangle(place: place, kind: kind)

            case let .scale(scale):
                return Rectangle(
                    center: picture.bounds.center,
                    width: picture.size.width / scale,
                    height: picture.size.height / scale
                )
            }
        }
    }

    // A position given by an area is the point it names on the area, padding included.
    func positions(
        _ property: PropertyValue<PositionForm>,
        clock: TimeMap,
        lengthScale: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<GeometryPoint> {
        try values(property, key: "position", clock: clock, place: place) { form, place in
            try point(form, lengthScale: lengthScale, place: place, kind: kind)
        }
    }

    // A path's vertices, each vertex's point found as a position is, at the place `place` gives for the keyframe that
    // writes it or nil for the static value, and its tangents as written.
    func vertices(
        _ vertices: [PathVertex<PropertyValue<PositionForm>, PropertyValue<Point>>],
        clock: TimeMap,
        lengthScale: Double,
        place: (_ index: Int, _ keyframe: Int?) -> Place,
        kind: String
    ) throws -> [PathVertex<PropertyValue<GeometryPoint>, PropertyValue<Point>>] {
        try vertices.enumerated().map { index, vertex in
            let found: PropertyValue<GeometryPoint> = switch vertex.vertex {
            case let .value(form):
                .value(try point(form, lengthScale: lengthScale, place: place(index, nil), kind: kind))

            case let .keyframes(keyframes):
                .keyframes(try keyframes.map { keyframe in
                    PropertyKeyframe(
                        index: keyframe.index,
                        at: clock.sequenceTime(ofClipTime: keyframe.at),
                        value: try point(
                            keyframe.value,
                            lengthScale: lengthScale,
                            place: place(index, keyframe.index),
                            kind: kind
                        ),
                        ease: keyframe.ease
                    )
                })
            }

            return PathVertex(
                vertex: found,
                inTangent: vertex.inTangent.inSequenceTime(on: clock),
                outTangent: vertex.outTangent.inSequenceTime(on: clock)
            )
        }
    }

    // A list of points under `key`, a corner pin's, each found as a position is, at the place of its index in the list.
    func points(
        _ property: PropertyValue<[PositionForm]>,
        key: String,
        clock: TimeMap,
        lengthScale: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<[GeometryPoint]> {
        try values(property, key: key, clock: clock, place: place) { forms, place in
            try forms.enumerated().map { index, form in
                try point(form, lengthScale: lengthScale, place: place.appending(index: index), kind: kind)
            }
        }
    }

    // A point in a picture, where a clip area stops as `AreaForm.rectangle(place:kind:)` says.
    func point(
        _ form: PositionForm,
        place: Place,
        kind: String
    ) throws -> Point {
        switch form {
        case let .point(point):
            return point

        case let .area(area, point):
            return try area.rectangle(place: place.appending(key: "area"), kind: kind).point(named: point)
        }
    }

    // MARK: - Private
    private func point(
        _ form: PositionForm,
        lengthScale: Double,
        place: Place,
        kind: String
    ) throws -> GeometryPoint {
        guard case let .area(area, name) = form, let area = ClipArea(form: area, lengthScale: lengthScale) else {
            return .point(try point(form, place: place, kind: kind))
        }

        return .clip(area, point: name)
    }

    private func values<Form, Found>(
        _ property: PropertyValue<Form>,
        key: String,
        clock: TimeMap,
        place: Place,
        find: (Form, Place) throws -> Found
    ) throws -> PropertyValue<Found> {
        switch property {
        case let .value(form):
            return .value(try find(form, place.appending(key: key)))

        case let .keyframes(keyframes):
            return .keyframes(try keyframes.map { keyframe in
                let keyframePlace = place.appending(key: "keyframes")
                    .appending(index: keyframe.index)
                    .appending(key: key)

                return PropertyKeyframe(
                    index: keyframe.index,
                    at: clock.sequenceTime(ofClipTime: keyframe.at),
                    value: try find(keyframe.value, keyframePlace),
                    ease: keyframe.ease
                )
            })
        }
    }
}
