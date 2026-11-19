//
//  LeafCheck.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A rule of a static value that its leaf's form and domain do not state. The key check stops a value that breaks it
// where it is written, and the theme merge stops one in the merged theme, so resolve reads only values it keeps.
enum LeafCheck: Equatable, Sendable {
    // A weight's name, or a whole number from 100 to 900, as `FontWeight(written:)` reads it.
    case fontWeight
    // Feature tags, each four printable ASCII characters and not `kern`, which `kerning` sets, to a whole number 0 or
    // more.
    case fontFeatures
    case positiveInteger

    // MARK: - Property
    var expectation: String {
        switch self {
        case .fontWeight:
            "a whole number from 100 to 900 or a weight name"

        case .fontFeatures:
            "an object of feature tags"

        case .positiveInteger:
            "a whole number, 1 or more"
        }
    }

    // A number is one of the values it takes, so a number parameter may stand for it.
    var takesNumber: Bool {
        switch self {
        case .fontWeight, .positiveInteger:
            true

        case .fontFeatures:
            false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // How `value` breaks the rule, or nil when it keeps it.
    func failure(of value: JSONValue) -> LeafCheckFailure? {
        switch self {
        case .fontWeight:
            guard FontWeight(written: value) == nil else { return nil }

            return value.stringValue.map { .unknownName($0, allowed: FontWeight.names.map(\.name)) } ?? .wrongValue

        case .fontFeatures:
            guard let object = value.objectValue else { return .wrongValue }

            return object.members.lazy.compactMap { featureFailure(of: $0) }.first

        case .positiveInteger:
            guard let number = value.numberValue, let integer = Int(exactly: number), integer > 0 else {
                return .wrongValue
            }

            return nil
        }
    }

    // MARK: - Private
    private func featureFailure(of member: JSONMember) -> LeafCheckFailure? {
        guard member.key != "kern" else { return .invalidMember(key: member.key, reason: "`kern` is set by `kerning`") }

        let isTag = member.key.unicodeScalars.count == 4
            && member.key.unicodeScalars.allSatisfy { (0x20...0x7E).contains($0.value) }
        guard isTag else {
            return .invalidMember(key: member.key, reason: "a feature tag is four printable ASCII characters")
        }
        guard let number = member.value.numberValue, Int(exactly: number) != nil, number >= 0 else {
            return .wrongMember(key: member.key)
        }

        return nil
    }
}
