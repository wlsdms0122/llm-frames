//
//  GeometryFinder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Finds the areas of one keyframable property: a static value at the clip's instant, and each keyframe at its own
// time, each turned into the media time of the picture it is found in. Keyframes come back in sequence time.
struct GeometryFinder: Sendable {
    // MARK: - Property
    private let finder: AreaFinder

    // MARK: - Initializer
    init(ocr: any OCRProvider) {
        self.finder = AreaFinder(ocr: ocr)
    }

    // MARK: - Public
    // `instant` is in sequence time and `clock` is the clip's, which its keyframes are written on. `padding` is in the
    // picture's pixels.
    func areas(
        _ property: PropertyValue<AreaForm>,
        key: String,
        in picture: Picture,
        pictureClock: PictureClock,
        clock: TimeMap,
        instant: Double,
        padding: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<FoundArea> {
        try values(property, key: key, clock: clock, instant: instant, place: place) { form, time, place in
            try area(
                form,
                in: picture,
                at: pictureClock.mediaTime(atSequenceTime: time),
                padding: padding,
                place: place,
                kind: kind
            )
        }
    }

    // `{scale: s}` is the centred region `1/s` the size of the picture.
    func crops(
        _ property: PropertyValue<CropForm>,
        in picture: Picture,
        pictureClock: PictureClock,
        clock: TimeMap,
        instant: Double,
        padding: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<FoundArea> {
        try values(property, key: "crop", clock: clock, instant: instant, place: place) { form, time, place in
            let mediaTime = pictureClock.mediaTime(atSequenceTime: time)
            switch form {
            case let .area(area):
                return try self.area(area, in: picture, at: mediaTime, padding: padding, place: place, kind: kind)

            case let .scale(scale):
                let region = Rectangle(
                    center: picture.bounds.center,
                    width: picture.size.width / scale,
                    height: picture.size.height / scale
                )
                return FoundArea(rectangle: region, target: region, isBand: false, mediaTime: mediaTime, lines: [])
            }
        }
    }

    // A position given by an area is the point it names on the area, padding included.
    func positions(
        _ property: PropertyValue<PositionForm>,
        in picture: Picture,
        pictureClock: PictureClock,
        clock: TimeMap,
        instant: Double,
        padding: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<Point> {
        try values(property, key: "position", clock: clock, instant: instant, place: place) { form, time, place in
            switch form {
            case let .point(point):
                return point

            case let .area(area, point):
                let found = try self.area(
                    area,
                    in: picture,
                    at: pictureClock.mediaTime(atSequenceTime: time),
                    padding: padding,
                    place: place.appending(key: "area"),
                    kind: kind
                )
                return found.rectangle.point(named: point)
            }
        }
    }

    func area(
        _ form: AreaForm,
        in picture: Picture,
        at mediaTime: Double,
        padding: Double,
        place: Place,
        kind: String
    ) throws -> FoundArea {
        try finder.area(form, in: picture, atMediaTime: mediaTime, padding: padding, place: place, kind: kind)
    }

    // MARK: - Private
    private func values<Form, Found>(
        _ property: PropertyValue<Form>,
        key: String,
        clock: TimeMap,
        instant: Double,
        place: Place,
        find: (Form, Double, Place) throws -> Found
    ) throws -> PropertyValue<Found> {
        switch property {
        case let .value(form):
            return .value(try find(form, instant, place.appending(key: key)))

        case let .keyframes(keyframes):
            return .keyframes(try keyframes.map { keyframe in
                let time = clock.sequenceTime(ofClipTime: keyframe.at)
                let keyframePlace = place.appending(key: "keyframes")
                    .appending(index: keyframe.index)
                    .appending(key: key)

                return TimedValue(
                    index: keyframe.index,
                    at: time,
                    value: try find(keyframe.value, time, keyframePlace),
                    ease: keyframe.ease
                )
            })
        }
    }
}
