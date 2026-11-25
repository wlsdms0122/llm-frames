//
//  TrackData.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A clip's `track` (FRAMES-12 Track data): `time` is the media time of the track's frame, and `frames` every frame
// followed, as written. The key table has checked that the object holds both keys and nothing else.
struct TrackData: Equatable, Sendable {
    // MARK: - Property
    let time: Double
    let frames: [TrackDataFrame]

    // MARK: - Initializer
    init(
        time: Double,
        frames: [TrackDataFrame]
    ) {
        self.time = time
        self.frames = frames
    }

    init?(value: JSONValue) {
        guard
            let object = value.objectValue,
            let time = object["time"]?.numberValue,
            let frames = object["frames"]?.arrayValue
        else {
            return nil
        }

        self.init(time: time, frames: frames.compactMap(TrackDataFrame.init(value:)))
    }

    // MARK: - Public
    // MARK: - Private
}
