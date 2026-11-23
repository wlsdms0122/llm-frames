//
//  MixerError.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

// `segment` is the segment's place in the plan, as `segments[1]` or `buses[0].segments[1]`, and `place` an op's, as
// `segments[1].filter[0].ops[2]` or `filter[0].ops[0]`.
package enum MixerError: Error, Equatable, CustomStringConvertible, Sendable {
    case noSound(segment: String, file: String)
    case unmixableChannels(segment: String, file: String)
    case unstretchable(segment: String, file: String, speed: Double)
    case unreadable(segment: String, reason: String)
    case unrenderable(file: String, reason: String)
    case unsupportedOperation(name: String, place: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .noSound(segment, file):
            "mix plan \(segment): media \(file) has no sound track"

        case let .unmixableChannels(segment, file):
            "mix plan \(segment): media \(file) has a channel ITU-R BS.775 names no speaker for, so it "
                + "is not downmixed to stereo"

        case let .unstretchable(segment, file, speed):
            "mix plan \(segment): media \(file) plays at speed \(speed), outside the 1/32 to 32 its time "
                + "stretch keeps the pitch over"

        case let .unreadable(segment, reason):
            "mix plan \(segment): \(reason)"

        case let .unrenderable(file, reason):
            "the sound of media \(file) cannot be mixed: \(reason)"

        case let .unsupportedOperation(name, place):
            "mix plan \(place): the avfoundation mixer has no audio operation \(name)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
