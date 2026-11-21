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
    case frameOfPage(place: Place, kind: String, written: String)
    case trackMatteSize(place: Place, kind: String, size: Size, listSize: Size)

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

        case let .frameOfPage(place, kind, written):
            "\(place) (\(kind)): frame \(written) is given for a page of a PDF, which is read by region and scale, "
                + "so its frame is null"

        case let .trackMatteSize(place, kind, size, listSize):
            "\(place) (\(kind)): the track matte's source is \(written(size)), and a track matte's source is the size "
                + "of the list that holds its item, \(written(listSize))"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }

    private func written(_ size: Size) -> String {
        "\(JSONValue.number(size.width).written) by \(JSONValue.number(size.height).written)"
    }
}
