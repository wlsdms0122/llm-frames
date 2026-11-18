//
//  TrackMatte.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A clip's track matte (FRAMES-11): `clip` the id of the matte clip in the same document, which is not drawn itself,
// how its picture cuts the clip, and whether that value is inverted. Resolve writes it as it is written.
struct TrackMatte: Equatable, Sendable {
    // MARK: - Property
    let clip: String
    let mode: TrackMatteMode
    let isInverted: Bool

    // MARK: - Initializer
    init(
        clip: String,
        mode: TrackMatteMode,
        isInverted: Bool
    ) {
        self.clip = clip
        self.mode = mode
        self.isInverted = isInverted
    }

    // A value that passed the key tables: `clip` and `mode` are there, and `invert` defaults to false.
    init?(value: JSONValue) {
        guard
            let object = value.objectValue,
            let clip = object["clip"]?.stringValue,
            let mode = object["mode"]?.stringValue.flatMap(TrackMatteMode.init(rawValue:))
        else {
            return nil
        }

        self.init(clip: clip, mode: mode, isInverted: object["invert"]?.boolValue ?? false)
    }

    // MARK: - Public
    // MARK: - Private
}
