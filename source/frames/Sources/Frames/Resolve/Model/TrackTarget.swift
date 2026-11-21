//
//  TrackTarget.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What `track` follows and the track's frame (FRAMES-12): the clip's own geometry, a named area, or track data, the
// quad of each frame followed. `time` is the media time of the track's frame where the object form names it, and nil
// for the short forms `true` and an area, whose frame is the one the clip's instant shows. The key table has checked
// the object form's keys.
enum TrackTarget: Equatable, Sendable {
    case own(time: Double?)
    case area(AreaForm, time: Double?)
    case data(time: Double, frames: [TrackDataFrame])

    // MARK: - Property
    var time: Double? {
        switch self {
        case let .own(time), let .area(_, time):
            time

        case let .data(time, _):
            time
        }
    }

    var isOwn: Bool {
        if case .own = self { true } else { false }
    }

    // MARK: - Initializer
    init?(value: JSONValue) {
        if value == .bool(true) {
            self = .own(time: nil)
            return
        }
        if let object = value.objectValue, ["time", "area", "frames"].contains(where: object.contains) {
            guard let time = object["time"]?.numberValue else { return nil }

            if let frames = object["frames"]?.arrayValue {
                self = .data(time: time, frames: frames.compactMap(TrackDataFrame.init(value:)))
            } else if let area = object["area"].flatMap(AreaForm.init(value:)) {
                self = .area(area, time: time)
            } else {
                self = .own(time: time)
            }
            return
        }
        guard let area = AreaForm(value: value) else { return nil }

        self = .area(area, time: nil)
    }

    // MARK: - Public
    // MARK: - Private
}
