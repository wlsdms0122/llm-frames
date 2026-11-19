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
    init(
        ocr: any OCRProvider,
        languages: [LanguageTag]?
    ) {
        self.finder = AreaFinder(ocr: ocr, languages: languages)
    }

    // MARK: - Public
    // `instant` is in sequence time and `clock` is the clip's, which its keyframes are written on.
    func areas(
        _ property: PropertyValue<AreaForm>,
        key: String,
        in picture: Picture,
        pictureClock: PictureClock,
        clock: TimeMap,
        instant: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<FoundArea> {
        try values(property, key: key, clock: clock, instant: instant, place: place) { form, time, place in
            try area(
                form,
                in: picture,
                at: pictureClock.mediaTime(atSequenceTime: time),
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
        place: Place,
        kind: String
    ) throws -> PropertyValue<FoundArea> {
        try values(property, key: "crop", clock: clock, instant: instant, place: place) { form, time, place in
            let mediaTime = pictureClock.mediaTime(atSequenceTime: time)
            switch form {
            case let .area(area):
                return try self.area(area, in: picture, at: mediaTime, place: place, kind: kind)

            case let .scale(scale):
                let region = Rectangle(
                    center: picture.bounds.center,
                    width: picture.size.width / scale,
                    height: picture.size.height / scale
                )
                return FoundArea(rectangle: region, target: region, mediaTime: mediaTime, lines: [])
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
        place: Place,
        kind: String
    ) throws -> PropertyValue<Point> {
        try values(property, key: "position", clock: clock, instant: instant, place: place) { form, time, place in
            try point(form, in: picture, at: pictureClock.mediaTime(atSequenceTime: time), place: place, kind: kind)
        }
    }

    // A path's points, each found as a position is, at the place of its index in the list.
    func points(
        _ property: PropertyValue<[PositionForm]>,
        in picture: Picture,
        pictureClock: PictureClock,
        clock: TimeMap,
        instant: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<[Point]> {
        try values(property, key: "points", clock: clock, instant: instant, place: place) { forms, time, place in
            try forms.enumerated().map { index, form in
                try point(
                    form,
                    in: picture,
                    at: pictureClock.mediaTime(atSequenceTime: time),
                    place: place.appending(index: index),
                    kind: kind
                )
            }
        }
    }

    // A clip's masks, each found in the space its geometry is written in.
    func masks(
        _ property: PropertyValue<[ClipMask]>,
        in picture: Picture,
        pictureClock: PictureClock,
        clock: TimeMap,
        instant: Double,
        lengthScale: Double,
        place: Place,
        kind: String
    ) throws -> PropertyValue<[ResolvedMask]> {
        try values(property, key: "mask", clock: clock, instant: instant, place: place) { masks, time, place in
            let mediaTime = pictureClock.mediaTime(atSequenceTime: time)
            return try masks.map { mask in
                let maskPlace = mask.index.map { place.appending(index: $0) } ?? place
                let geometry: FoundMaskGeometry
                switch mask.geometry {
                case let .area(area):
                    let found = try self.area(
                        area,
                        in: picture,
                        at: mediaTime,
                        place: maskPlace.appending(key: "area"),
                        kind: kind
                    )
                    geometry = .area(found.rectangle)

                case let .box(width, height, position):
                    let center = try point(
                        position,
                        in: picture,
                        at: mediaTime,
                        place: maskPlace.appending(key: "position"),
                        kind: kind
                    )
                    geometry = .box(width: width, height: height, position: center)

                case let .points(forms):
                    geometry = .points(try forms.enumerated().map { index, form in
                        try point(
                            form,
                            in: picture,
                            at: mediaTime,
                            place: maskPlace.appending(key: "points").appending(index: index),
                            kind: kind
                        )
                    })
                }

                return ResolvedMask(mask: mask, geometry: geometry, lengthScale: lengthScale)
            }
        }
    }

    func area(
        _ form: AreaForm,
        in picture: Picture,
        at mediaTime: Double,
        place: Place,
        kind: String
    ) throws -> FoundArea {
        try finder.area(form, in: picture, atMediaTime: mediaTime, place: place, kind: kind)
    }

    // MARK: - Private
    private func point(
        _ form: PositionForm,
        in picture: Picture,
        at mediaTime: Double,
        place: Place,
        kind: String
    ) throws -> Point {
        switch form {
        case let .point(point):
            return point

        case let .area(area, point):
            let found = try self.area(area, in: picture, at: mediaTime, place: place.appending(key: "area"), kind: kind)
            return found.rectangle.point(named: point)
        }
    }

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

                return PropertyKeyframe(
                    index: keyframe.index,
                    at: time,
                    value: try find(keyframe.value, time, keyframePlace),
                    ease: keyframe.ease
                )
            })
        }
    }
}
