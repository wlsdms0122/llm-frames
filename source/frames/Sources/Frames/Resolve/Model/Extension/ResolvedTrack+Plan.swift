//
//  ResolvedTrack+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What the tracker followed for a property, which is a band when all of its values are bands, as resolve measures a
// label through it.
extension ResolvedTrack {
    // MARK: - Property
    // MARK: - Initializer
    // `values` are the values of the property that follows the track, nil for one that is not an area.
    init(
        track: Track,
        values: PropertyValue<FoundArea>?
    ) {
        let isBand = switch values {
        case let .value(found):
            found.isBand

        case let .keyframes(keyframes):
            keyframes.allSatisfy(\.value.isBand)

        case nil:
            false
        }

        self.init(target: track.target, mediaTime: track.mediaTime, isBand: isBand, frames: track.frames)
    }

    // MARK: - Public
    // MARK: - Private
}
