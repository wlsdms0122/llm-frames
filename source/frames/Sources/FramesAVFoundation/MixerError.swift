//
//  MixerError.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import Frames

// `place` is the place in the plan of what is read: a segment, as `segments[1]` or `buses[0].segments[1]`, or a
// `convolve` op, whose impulse response is read, as `segments[1].filter[0].ops[2]` or `filter[0].ops[0]`.
package enum MixerError: Error, Equatable, CustomStringConvertible, Sendable {
    case noSound(place: String, file: String)
    case unmixableChannels(place: String, file: String)
    case noChannelLayout(place: String, file: String, channels: Int)
    case unstretchable(place: String, file: String, speed: Double)
    case unreadable(place: String, reason: String)
    case unrenderable(file: String, reason: String)
    case emptyImpulseResponse(place: String, file: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .noSound(place, file):
            "mix plan \(place): media \(file) has no sound track"

        case let .unmixableChannels(place, file):
            "mix plan \(place): media \(file) has a channel ITU-R BS.775 names no speaker for, so it "
                + "is not downmixed to stereo"

        case let .noChannelLayout(place, file, channels):
            "mix plan \(place): media \(file) has \(channels) channels and its file names no channel layout, so it is "
                + "not downmixed to stereo"

        case let .unstretchable(place, file, speed):
            "mix plan \(place): media \(file) plays at speed \(speed), outside the 1/32 to 32 its time "
                + "stretch keeps the pitch over"

        case let .unreadable(place, reason):
            "mix plan \(place): \(reason)"

        case let .unrenderable(file, reason):
            "the sound of media \(file) cannot be mixed: \(reason)"

        case let .emptyImpulseResponse(place, file):
            "mix plan \(place): the impulse response \(file) has no samples"
        }
    }

    // MARK: - Initializer
    // The refusal of the sound of `file`, of `layout`, that is not downmixed to stereo.
    init(
        undownmixable layout: ChannelLayout,
        place: String,
        file: String
    ) {
        self = layout.labels.contains(.unknown)
            ? .noChannelLayout(place: place, file: file, channels: layout.labels.count)
            : .unmixableChannels(place: place, file: file)
    }

    // MARK: - Public
    // MARK: - Private
}
