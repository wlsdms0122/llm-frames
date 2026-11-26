//
//  ParameterError.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The arguments given to the published parameters of a template or a preset that do not match them.
enum ParameterError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownArgument(place: Place, kind: String, name: String, allowed: [String])
    case missingArgument(place: Place, kind: String, name: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .unknownArgument(place, kind, name, allowed):
            "\(place) (\(kind)): unknown argument \(quoted(name)). "
                + (allowed.isEmpty ? "It publishes no parameters" : "Allowed: \(allowed.joined(separator: ", "))")
                + NameHint.suggestion(for: name, among: allowed)

        case let .missingArgument(place, kind, name):
            "\(place) (\(kind)): missing argument \(quoted(name)), which has no default"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
