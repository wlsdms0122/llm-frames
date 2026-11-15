//
//  ModelError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ModelError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownKey(place: Place, kind: String, key: String, allowed: [String])
    case missingKey(place: Place, kind: String, keys: [String])
    case conflictingKeys(place: Place, kind: String, keys: [String])
    case wrongType(place: Place, kind: String, expected: String, found: String)
    case unknownValue(place: Place, kind: String, value: String, allowed: [String])
    case invalidValue(place: Place, kind: String, reason: String)
    case duplicateIdentifier(place: Place, kind: String, id: String, first: Place)
    case staticAndKeyframed(place: Place, kind: String, property: String)
    case unknownParameter(place: Place, kind: String, name: String)
    case misplacedParameter(place: Place, kind: String, name: String, type: String, expected: String)
    case unusedParameter(place: Place, name: String)
    case nestedTemplate(place: Place, kind: String)
    case unprobedMedia(place: Place, kind: String, reference: String)
    case ambiguousTemplateKind(place: Place, kind: String, name: String, templates: [String], kinds: [MediaKind])
    case misplacedMedia(place: Place, kind: String, reason: String)
    case easeWithoutFollowingKeyframe(place: Place, properties: [String])

    // MARK: - Property
    var description: String {
        switch self {
        case let .unknownKey(place, kind, key, allowed):
            "\(place) (\(kind)): unknown key \"\(key)\". Allowed: \(allowed.joined(separator: ", "))"

        case let .missingKey(place, kind, keys) where keys.count == 1:
            "\(place) (\(kind)): missing key \"\(keys[0])\""

        case let .missingKey(place, kind, keys):
            "\(place) (\(kind)): needs one of \(keys.joined(separator: ", "))"

        case let .conflictingKeys(place, kind, keys):
            "\(place) (\(kind)): takes only one of \(keys.map { "\"\($0)\"" }.joined(separator: ", "))"

        case let .wrongType(place, kind, expected, found):
            "\(place) (\(kind)): expected \(expected), found \(found)"

        case let .unknownValue(place, kind, value, allowed):
            "\(place) (\(kind)): unknown value \"\(value)\". Allowed: \(allowed.joined(separator: ", "))"

        case let .invalidValue(place, kind, reason):
            "\(place) (\(kind)): \(reason)"

        case let .duplicateIdentifier(place, kind, id, first):
            "\(place) (\(kind)): id \"\(id)\" is already used at \(first)"

        case let .staticAndKeyframed(place, kind, property):
            "\(place) (\(kind)): \"\(property)\" is written both as a static value and in a keyframe"

        case let .unknownParameter(place, kind, name):
            "\(place) (\(kind)): parameter \"\(name)\" is not declared in params"

        case let .misplacedParameter(place, kind, name, type, expected):
            "\(place) (\(kind)): parameter \"\(name)\" of type \(type) cannot stand where \(expected) is expected"

        case let .unusedParameter(place, name):
            "\(place) (parameter): \"\(name)\" is declared but nothing in the template refers to it"

        case let .nestedTemplate(place, kind):
            "\(place) (\(kind)): a document with params is a template and is used only as a template instance"

        case let .unprobedMedia(place, kind, reference):
            "\(place) (\(kind)): media \"\(reference)\" has no probed kind"

        case let .ambiguousTemplateKind(place, kind, name, templates, kinds):
            "\(place) (\(kind)): parameter \"\(name)\" names templates of different kinds: "
                + zip(templates, kinds).map { "\"\($0)\" is \($1.rawValue)" }.joined(separator: ", ")

        case let .misplacedMedia(place, kind, reason):
            "\(place) (\(kind)): \(reason)"

        case let .easeWithoutFollowingKeyframe(place, properties):
            "\(place) (keyframe): \"ease\" shapes no span, since no later keyframe names \(properties.joined(separator: ", "))"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
