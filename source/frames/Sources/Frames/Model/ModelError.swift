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
    case outsideDomain(place: Place, kind: String, value: Double, domain: NumberDomain)
    case unknownValue(place: Place, kind: String, value: String, allowed: [String])
    case invalidValue(place: Place, kind: String, reason: String)
    case duplicateIdentifier(place: Place, kind: String, id: String, first: Place)
    case staticAndKeyframed(place: Place, kind: String, property: String)
    case staticKeyframedOnly(place: Place, kind: String, property: String)
    case unknownParameter(place: Place, kind: String, name: String)
    case misplacedParameter(place: Place, kind: String, name: String, type: String, expected: String)
    case unusedParameter(place: Place, name: String)
    case nestedTemplate(place: Place, kind: String)
    case unknownReference(place: Place, kind: String, reference: UnknownReference)
    case unreadableMedia(place: Place, kind: String, reference: String, reason: String)
    case unnamedPage(place: Place, kind: String, reference: String, pageCount: Int)
    case missingPage(place: Place, kind: String, reference: String, page: Int, pageCount: Int)
    case pageOfNonPDF(place: Place, kind: String, reference: String)
    case highDynamicRangePage(place: Place, kind: String, reference: String, page: Int, colorSpace: ColorSpace)
    case misplacedMedia(place: Place, kind: String, reason: String)
    case easeWithoutFollowingKeyframe(place: Place, leaves: [Place])
    case request(place: Place, tool: String)

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

        case let .outsideDomain(place, kind, value, domain):
            "\(place) (\(kind)): \(domain.refusal(of: value))"

        case let .unknownValue(place, kind, value, allowed):
            "\(place) (\(kind)): unknown value \"\(value)\". Allowed: \(allowed.joined(separator: ", "))"

        case let .invalidValue(place, kind, reason):
            "\(place) (\(kind)): \(reason)"

        case let .duplicateIdentifier(place, kind, id, first):
            "\(place) (\(kind)): id \"\(id)\" is already used at \(first)"

        case let .staticAndKeyframed(place, kind, property):
            "\(place) (\(kind)): \"\(property)\" is written both as a static value and in a keyframe"

        case let .staticKeyframedOnly(place, kind, property):
            "\(place) (\(kind)): \"\(property)\" is written only in keyframes, so a static value has no meaning"

        case let .unknownParameter(place, kind, name):
            "\(place) (\(kind)): parameter \"\(name)\" is not declared in params"

        case let .misplacedParameter(place, kind, name, type, expected):
            "\(place) (\(kind)): parameter \"\(name)\" of type \(type) cannot stand where \(expected) is expected"

        case let .unusedParameter(place, name):
            "\(place) (parameter): \"\(name)\" is declared but nothing refers to it"

        case let .nestedTemplate(place, kind):
            "\(place) (\(kind)): a document with params is a template and is used only as a template instance"

        case let .unknownReference(place, kind, reference):
            "\(place) (\(kind)): \(reference)"

        case let .unreadableMedia(place, kind, reference, reason):
            "\(place) (\(kind)): media \"\(reference)\" cannot be probed: \(reason)"

        case let .unnamedPage(place, kind, reference, pageCount):
            "\(place) (\(kind)): media \"\(reference)\" is a PDF of \(pageCount) pages, more than one picture, so a page of it is named as {\"file\", \"page\"}"

        case let .missingPage(place, kind, reference, page, pageCount):
            "\(place) (\(kind)): media \"\(reference)\" has \(pageCount) pages, so it has no page \(page)"

        case let .pageOfNonPDF(place, kind, reference):
            "\(place) (\(kind)): media \"\(reference)\" is not a PDF, so it has no pages"

        case let .highDynamicRangePage(place, kind, reference, page, colorSpace):
            "\(place) (\(kind)): media \"\(reference)\" page \(page) is not HDR, so it is read in a colour space of standard dynamic range, not \"\(colorSpace.rawValue)\". Allowed: \(VocabularyTable.standardDynamicRangeColorSpaces.joined(separator: ", "))"

        case let .misplacedMedia(place, kind, reason):
            "\(place) (\(kind)): \(reason)"

        case let .easeWithoutFollowingKeyframe(place, leaves):
            "\(place) (keyframe): \"ease\" shapes no span, since no later keyframe names \(leaves.map(\.description).joined(separator: ", "))"

        case let .request(place, tool):
            "\(place) (request): this is a request for the tool \"\(tool)\", and a tool fills its requests before the document is given to frames"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
