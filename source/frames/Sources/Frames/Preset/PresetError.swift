//
//  PresetError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum PresetError: Error, Equatable, CustomStringConvertible, Sendable {
    case matteOverOutgoing(place: Place)
    case progressOutOfRange(place: Place, t: Double)
    case nonPositiveLength(place: Place, kind: String, length: Double)
    case parameterOutOfRange(place: Place, kind: String, value: String, range: String)
    case rejectedArguments(place: Place, kind: String, name: String, reason: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .matteOverOutgoing(place):
            "\(place) (transition): a matte reveals the incoming storyline picture, so it cannot play with \"over\": \"outgoing\""

        case let .progressOutOfRange(place, t):
            "\(place) (span key): t is progress through the span and lies between 0 and 1, found \(JSONValue.number(t).written)"

        case let .nonPositiveLength(place, kind, length):
            "\(place) (\(kind)): a span runs for more than 0 seconds, found \(JSONValue.number(length).written)"

        case let .parameterOutOfRange(place, kind, value, range):
            "\(place) (\(kind)): \(value) is not \(range)"

        case let .rejectedArguments(place, kind, name, reason):
            "\(place) (\(kind)): its arguments give \(JSONValue.string(name).written) a value it does not take: \(reason)"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
