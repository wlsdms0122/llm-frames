//
//  MixerError.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

package enum MixerError: Error, Equatable, CustomStringConvertible, Sendable {
    case noSound(segment: Int, file: String)
    case unmixableChannels(segment: Int, file: String)
    case unstretchable(segment: Int, file: String, speed: Double)
    case unreadable(segment: Int, reason: String)
    case unrenderable(file: String, reason: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .noSound(segment, file):
            "mix plan segments[\(segment)]: media \(file) has no sound track"

        case let .unmixableChannels(segment, file):
            "mix plan segments[\(segment)]: media \(file) has a channel ITU-R BS.775 names no speaker for, so it "
                + "is not downmixed to stereo"

        case let .unstretchable(segment, file, speed):
            "mix plan segments[\(segment)]: media \(file) plays at speed \(speed), outside the 1/32 to 32 its time "
                + "stretch keeps the pitch over"

        case let .unreadable(segment, reason):
            "mix plan segments[\(segment)]: \(reason)"

        case let .unrenderable(file, reason):
            "the sound of media \(file) cannot be mixed: \(reason)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
