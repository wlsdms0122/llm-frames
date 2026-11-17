//
//  EvaluateError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

enum EvaluateError: Error, Equatable, CustomStringConvertible, Sendable {
    // `form` is what was read, `display list` or `mix plan`.
    case unreadableVersion(place: Place, kind: String, form: String, written: String, current: String)
    case differentSeed(place: Place, kind: String, seed: Int, listSeed: Int)
    case frameOutOfRange(place: Place, kind: String, frame: Int, count: Int)

    // MARK: - Property
    var description: String {
        switch self {
        case let .unreadableVersion(place, kind, form, written, current):
            "\(place) (\(kind)): the \(form) was written by frames \(quoted(written)), and frames \(current) reads "
                + "only one written by frames \(current.split(separator: ".").prefix(1).joined()).0 up to "
                + "\(current.split(separator: ".").prefix(2).joined(separator: "."))"

        case let .differentSeed(place, kind, seed, listSeed):
            "\(place) (\(kind)): seed \(seed) differs from \(listSeed), the seed of the first grain in the list, and "
                + "every grain of an output frame takes that frame's number"

        case let .frameOutOfRange(place, kind, frame, count):
            "\(place) (\(kind)): frame \(frame) is not a frame of the media, whose frames are 0 to \(count - 1)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
