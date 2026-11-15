//
//  KeyChecker.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct KeyChecker: Sendable {
    // MARK: - Property
    private let mediaKinds: any MediaKindProvider
    private let keyframeReader = KeyframeReader()

    // MARK: - Initializer
    init(mediaKinds: any MediaKindProvider = MediaKindTable()) {
        self.mediaKinds = mediaKinds
    }

    // MARK: - Public
    func check(document: JSONValue) throws {
        var scope = DocumentScope()
        _ = try checkDocument(
            document,
            place: .root,
            kind: "document",
            isNested: false,
            scope: &scope
        )
    }

    func check(
        _ value: JSONValue,
        as table: ObjectTable
    ) throws {
        var scope = DocumentScope()
        try check(
            value,
            as: .object(table),
            place: .root,
            kind: table.kind,
            scope: &scope
        )
    }

    // MARK: - Private
    private func check(
        _ value: JSONValue,
        as type: ValueType,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        if case let .object(object) = value, object.contains("param"), takesParameter(type) {
            try checkParameterReference(object, as: type, place: place, kind: kind, scope: &scope)
            return
        }

        switch type {
        case .anyValue:
            return

        case .argument:
            // An argument's type is the template's to say, but a document given as one is checked as any document.
            guard isDocument(value) else { return }

            _ = try checkDocument(value, place: place, kind: kind, isNested: true, scope: &scope)

        case let .exactly(expected):
            guard value == expected else { throw wrongType(value, type, place, kind) }

        case .anyObject, .bool, .number, .text, .name:
            guard admits(type, value) else { throw wrongType(value, type, place, kind) }

        case .integer:
            guard let number = value.numberValue, number.rounded() == number else {
                throw wrongType(value, type, place, kind)
            }

        case .color, .hexColor:
            try checkColor(value, as: type, place: place, kind: kind)

        case .identifier:
            try checkIdentifier(value, place: place, kind: kind, scope: &scope)

        case .ease:
            try checkEase(value, place: place, kind: kind)

        case let .literal(names):
            guard let string = value.stringValue else { throw wrongType(value, type, place, kind) }
            guard names.contains(string) else {
                throw ModelError.unknownValue(place: place, kind: kind, value: string, allowed: names)
            }

        case let .numbers(count):
            guard let elements = value.arrayValue, elements.count == count else {
                throw wrongType(value, type, place, kind)
            }

            for (index, element) in elements.enumerated() {
                try check(element, as: .number, place: place.appending(index: index), kind: kind, scope: &scope)
            }

        case let .list(elementType):
            guard let elements = value.arrayValue else { throw wrongType(value, type, place, kind) }
            for (index, element) in elements.enumerated() {
                try check(element, as: elementType, place: elementPlace(place, index, element), kind: kind, scope: &scope)
            }

        case let .map(valueType, mapKind):
            guard let object = value.objectValue else { throw wrongType(value, type, place, kind) }
            for member in object.members {
                try check(member.value, as: valueType, place: place.appending(key: member.key), kind: mapKind, scope: &scope)
            }

        case let .object(table):
            guard let object = value.objectValue else { throw wrongType(value, type, place, kind) }
            try checkObject(object, as: table, place: place, scope: &scope)

        case let .oneOf(types):
            try checkAlternatives(value, as: types, place: place, kind: kind, scope: &scope)

        case .area:
            try checkArea(value, place: place, kind: kind, scope: &scope)

        case .crop:
            if case let .object(object) = value, object.contains("scale") {
                try checkObject(object, as: AreaKeyTable.cropScale, place: place, scope: &scope)
            } else {
                try checkArea(value, place: place, kind: kind, scope: &scope)
            }

        case .media:
            _ = try checkMedia(value, place: place, kind: kind, lookup: false, scope: &scope)

        case .document:
            _ = try checkDocument(value, place: place, kind: kind, isNested: true, scope: &scope)

        case let .clips(clipPlace):
            guard let elements = value.arrayValue else { throw wrongType(value, type, place, kind) }
            for (index, element) in elements.enumerated() {
                try checkClip(element, place: elementPlace(place, index, element), in: clipPlace, scope: &scope)
            }

        case .operations:
            guard let elements = value.arrayValue else { throw wrongType(value, type, place, kind) }
            for (index, element) in elements.enumerated() {
                try checkOperation(element, place: elementPlace(place, index, element), scope: &scope)
            }

        case .parameters:
            guard let object = value.objectValue else { throw wrongType(value, type, place, kind) }
            for member in object.members {
                try checkParameter(member.value, place: place.appending(key: member.key), scope: &scope)
            }

        case .filterOperation:
            try checkFilterOperation(value, place: place, kind: kind, scope: &scope)
        }
    }

    private func checkObject(
        _ object: JSONObject,
        as table: ObjectTable,
        place: Place,
        skipping skipped: Set<String> = [],
        scope: inout DocumentScope
    ) throws {
        for member in object.members {
            guard let rule = table.rule(named: member.key) else {
                throw ModelError.unknownKey(place: place, kind: table.kind, key: member.key, allowed: table.keys)
            }
            guard !skipped.contains(member.key) else { continue }

            try check(member.value, as: rule.type, place: place.appending(key: member.key), kind: table.kind, scope: &scope)
        }

        for rule in table.rules where rule.isRequired && !object.contains(rule.name) {
            throw ModelError.missingKey(place: place, kind: table.kind, keys: [rule.name])
        }

        guard let group = table.group else { return }

        let present = group.keys.filter(object.contains)
        guard !present.isEmpty else {
            throw ModelError.missingKey(place: place, kind: table.kind, keys: group.keys)
        }
        guard !group.isExclusive || present.count == 1 else {
            throw ModelError.conflictingKeys(place: place, kind: table.kind, keys: present)
        }
    }

    private func checkAlternatives(
        _ value: JSONValue,
        as types: [ValueType],
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        var failures: [Error] = []
        for type in types {
            var trial = scope
            do {
                try check(value, as: type, place: place, kind: kind, scope: &trial)
                scope = trial
                return
            } catch {
                failures.append(error)
            }
        }

        // When only one alternative takes this kind of value, its own error says more than a list of every form.
        let admitting = types.indices.filter { admits(types[$0], value) }
        guard admitting.count == 1 else {
            throw wrongType(value, .oneOf(types), place, kind)
        }

        throw failures[admitting[0]]
    }

    private func checkColor(
        _ value: JSONValue,
        as type: ValueType,
        place: Place,
        kind: String
    ) throws {
        guard let string = value.stringValue else { throw wrongType(value, type, place, kind) }

        let isHex = string.hasPrefix("#")
        if case .hexColor = type, !isHex {
            throw ModelError.invalidValue(place: place, kind: kind, reason: "\"\(string)\" is not #RRGGBB or #RRGGBBAA")
        }
        guard isHex else { return }

        let digits = string.dropFirst()
        guard [6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else {
            throw ModelError.invalidValue(place: place, kind: kind, reason: "\"\(string)\" is not #RRGGBB or #RRGGBBAA")
        }
    }

    private func checkIdentifier(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let id = value.stringValue else { throw wrongType(value, .identifier, place, kind) }

        let owner = Place(components: Array(place.components.dropLast()))
        if let first = scope.identifiers[id] {
            throw ModelError.duplicateIdentifier(place: owner, kind: kind, id: id, first: first)
        }

        scope.identifiers[id] = owner
    }

    private func checkEase(
        _ value: JSONValue,
        place: Place,
        kind: String
    ) throws {
        switch value {
        case let .string(name):
            guard VocabularyTable.easeNames.contains(name) else {
                throw ModelError.unknownValue(
                    place: place,
                    kind: kind,
                    value: name,
                    allowed: VocabularyTable.easeNames + ["[x1, y1, x2, y2]"]
                )
            }

        case let .array(elements):
            let numbers = elements.compactMap(\.numberValue)
            guard elements.count == 4, numbers.count == 4 else {
                throw wrongType(value, .ease, place, kind)
            }
            guard (0...1).contains(numbers[0]), (0...1).contains(numbers[2]) else {
                throw ModelError.invalidValue(place: place, kind: kind, reason: "a cubic Bézier's x1 and x2 lie between 0 and 1")
            }

        default:
            throw wrongType(value, .ease, place, kind)
        }
    }

    private func checkArea(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        switch value {
        case .array:
            try check(value, as: .numbers(4), place: place, kind: kind, scope: &scope)

        case .string:
            return

        case let .object(object):
            if object.contains("band") {
                try checkObject(object, as: AreaKeyTable.band, place: place, scope: &scope)
            } else if object.contains("text") {
                try checkObject(object, as: AreaKeyTable.text, place: place, scope: &scope)
            } else if object.contains("from") || object.contains("to") {
                try checkObject(object, as: AreaKeyTable.range, place: place, scope: &scope)
            } else {
                throw ModelError.missingKey(place: place, kind: "area", keys: ["text", "from", "band"])
            }

        default:
            throw wrongType(value, .area, place, kind)
        }
    }

    private func checkMedia(
        _ value: JSONValue,
        place: Place,
        kind: String,
        lookup: Bool,
        scope: inout DocumentScope
    ) throws -> MediaKind? {
        switch value {
        case let .string(reference):
            return try lookup ? probedKind(of: reference, place: place, kind: kind) : nil

        case let .object(object) where object.contains("param"):
            return try checkMediaParameter(object, place: place, kind: kind, scope: &scope)

        case let .object(object) where object.contains("kind"):
            let documentKind = try checkDocument(value, place: place, kind: kind, isNested: true, scope: &scope)
            return documentKind == "sequence" ? .sequence : .image

        case let .object(object) where object.contains("imageSequence"):
            try checkObject(object, as: TemplateKeyTable.imageSequence, place: place, scope: &scope)
            return .video

        case let .object(object) where object.contains("template"):
            try checkObject(object, as: TemplateKeyTable.instance, place: place, scope: &scope)
            guard lookup, let template = object["template"]?.stringValue else { return nil }

            return try probedKind(of: template, place: place, kind: kind)

        case .object:
            throw ModelError.missingKey(place: place, kind: "media", keys: ["kind", "imageSequence", "template"])

        default:
            throw wrongType(value, .media, place, kind)
        }
    }

    private func probedKind(
        of reference: String,
        place: Place,
        kind: String
    ) throws -> MediaKind {
        guard let mediaKind = mediaKinds.mediaKind(of: reference) else {
            throw ModelError.unprobedMedia(place: place, kind: kind, reference: reference)
        }

        return mediaKind
    }

    private func checkDocument(
        _ value: JSONValue,
        place: Place,
        kind: String,
        isNested: Bool,
        scope: inout DocumentScope
    ) throws -> String {
        guard let object = value.objectValue else { throw wrongType(value, .document, place, kind) }
        guard let kindValue = object["kind"] else {
            throw ModelError.missingKey(place: place, kind: kind, keys: ["kind"])
        }
        guard let documentKind = kindValue.stringValue else {
            throw wrongType(kindValue, .text, place.appending(key: "kind"), "document")
        }
        guard let table = DocumentKeyTable.table(for: documentKind) else {
            throw ModelError.unknownValue(
                place: place.appending(key: "kind"),
                kind: "document",
                value: documentKind,
                allowed: VocabularyTable.documentKinds
            )
        }

        guard !isNested else {
            guard !object.contains("params") else {
                throw ModelError.nestedTemplate(place: place, kind: documentKind)
            }

            // A nested document has ids of its own, while a template's parameters reach into it.
            let outerIdentifiers = scope.identifiers
            scope.identifiers = [:]
            try checkObject(object, as: table, place: place, scope: &scope)
            scope.identifiers = outerIdentifiers
            return documentKind
        }

        // Parameters are read first, so a reference written before `params` still finds its declaration.
        let parameters = object["params"]?.objectValue?.members ?? []
        scope.parameters = Dictionary(
            parameters.compactMap { member in member.value.objectValue.map { (member.key, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        try checkObject(object, as: table, place: place, scope: &scope)

        for member in parameters where !scope.usedParameters.contains(member.key) {
            throw ModelError.unusedParameter(place: place.appending(key: "params").appending(key: member.key), name: member.key)
        }

        return documentKind
    }

    private func checkClip(
        _ value: JSONValue,
        place: Place,
        in clipPlace: ClipPlace,
        scope: inout DocumentScope
    ) throws {
        let generic = clipPlace == .storyline ? "storyline clip" : "clip"
        guard let object = value.objectValue else {
            throw wrongType(value, .object(ObjectTable(kind: generic, rules: [])), place, generic)
        }

        let allowed = ClipKeyTable.kindKeys(in: clipPlace)
        let present = ClipKeyTable.kindKeys.filter(object.contains)
        guard !present.isEmpty else {
            throw ModelError.missingKey(place: place, kind: generic, keys: allowed)
        }
        guard present.count == 1 else {
            throw ModelError.conflictingKeys(place: place, kind: generic, keys: present)
        }
        guard allowed.contains(present[0]) else {
            throw ModelError.unknownKey(place: place, kind: generic, key: present[0], allowed: allowed)
        }

        let clipKind = try clipKind(of: object, by: present[0], place: place, in: clipPlace, scope: &scope)
        let table = ClipKeyTable.table(for: clipKind, in: clipPlace)
        try checkObject(object, as: table, place: place, skipping: ["media"], scope: &scope)
        try checkStaticAndKeyframed(object, kind: clipKind, place: place, in: clipPlace)

        if let keyframes = object["keyframes"] {
            try keyframeReader.checkEases(in: keyframes, place: place.appending(key: "keyframes"))
        }
    }

    private func clipKind(
        of object: JSONObject,
        by key: String,
        place: Place,
        in clipPlace: ClipPlace,
        scope: inout DocumentScope
    ) throws -> ClipKind {
        let generic = clipPlace == .storyline ? "storyline clip" : "clip"

        switch key {
        case "media":
            let media = object["media"] ?? .null
            let mediaKind = try checkMedia(
                media,
                place: place.appending(key: "media"),
                kind: generic,
                lookup: true,
                scope: &scope
            )
            guard let mediaKind else {
                throw ModelError.unprobedMedia(place: place.appending(key: "media"), kind: generic, reference: "\(media)")
            }
            guard clipPlace != .storyline || mediaKind != .audio else {
                throw ModelError.misplacedMedia(
                    place: place,
                    kind: ClipKind.media(.audio).label,
                    reason: "a storyline clip needs a picture, and this media holds only sound"
                )
            }

            return .media(mediaKind)

        case "shape":
            let shape = object["shape"] ?? .null
            try check(
                shape,
                as: .literal(VocabularyTable.shapes),
                place: place.appending(key: "shape"),
                kind: "shape",
                scope: &scope
            )
            return .shape(shape.stringValue ?? "")

        case "title":
            return .title

        case "adjust":
            return .adjust

        default:
            return .solid
        }
    }

    private func checkStaticAndKeyframed(
        _ object: JSONObject,
        kind: ClipKind,
        place: Place,
        in clipPlace: ClipPlace
    ) throws {
        guard let keyframes = object["keyframes"]?.arrayValue else { return }

        let properties = ClipKeyTable.keyframable(for: kind, in: clipPlace)
        for keyframe in keyframes.compactMap(\.objectValue) {
            for property in properties where keyframe.contains(property) && object.contains(property) {
                throw ModelError.staticAndKeyframed(place: place, kind: kind.label, property: property)
            }
        }
    }

    private func checkOperation(
        _ value: JSONValue,
        place: Place,
        scope: inout DocumentScope
    ) throws {
        guard let object = value.objectValue else {
            throw wrongType(value, .object(ObjectTable(kind: "operation", rules: [])), place, "operation")
        }

        let keys = ImageKeyTable.operationKeys
        let present = keys.filter(object.contains)
        guard !present.isEmpty else {
            throw ModelError.missingKey(place: place, kind: "operation", keys: keys)
        }
        guard present.count == 1 else {
            throw ModelError.conflictingKeys(place: place, kind: "operation", keys: present)
        }

        var shape: String?
        if present[0] == "shape" {
            let value = object["shape"] ?? .null
            try check(
                value,
                as: .literal(VocabularyTable.shapes),
                place: place.appending(key: "shape"),
                kind: "shape",
                scope: &scope
            )
            shape = value.stringValue
        }

        try checkObject(object, as: ImageKeyTable.table(for: present[0], shape: shape), place: place, scope: &scope)
    }

    private func checkParameter(
        _ value: JSONValue,
        place: Place,
        scope: inout DocumentScope
    ) throws {
        let table = TemplateKeyTable.parameter
        guard let object = value.objectValue else { throw wrongType(value, .object(table), place, table.kind) }

        try checkObject(object, as: table, place: place, skipping: ["default"], scope: &scope)

        let type = object["type"]?.stringValue ?? ""
        let isChoice = type == "choice"
        if isChoice, !object.contains("options") {
            throw ModelError.missingKey(place: place, kind: table.kind, keys: ["options"])
        }
        if !isChoice, object.contains("options") {
            throw ModelError.unknownKey(
                place: place,
                kind: table.kind,
                key: "options",
                allowed: ["type", "default", "description"]
            )
        }

        guard let defaultValue = object["default"] else { return }

        let options = object["options"]?.arrayValue?.compactMap(\.stringValue) ?? []
        var defaultScope = scope
        try check(
            defaultValue,
            as: defaultType(of: type, options: options),
            place: place.appending(key: "default"),
            kind: table.kind,
            scope: &defaultScope
        )
    }

    private func defaultType(
        of parameterType: String,
        options: [String]
    ) -> ValueType {
        switch parameterType {
        case "text":
            .text

        case "color":
            .color

        case "number":
            .number

        case "choice":
            .literal(options)

        default:
            .media
        }
    }

    private func checkParameterReference(
        _ object: JSONObject,
        as type: ValueType,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        for key in object.keys where key != "param" {
            throw ModelError.unknownKey(place: place, kind: "parameter reference", key: key, allowed: ["param"])
        }

        let nameValue = object["param"] ?? .null
        guard let name = nameValue.stringValue else {
            throw wrongType(nameValue, .name, place.appending(key: "param"), "parameter reference")
        }
        guard let parameter = scope.parameters[name] else {
            throw ModelError.unknownParameter(place: place, kind: kind, name: name)
        }

        scope.usedParameters.insert(name)

        let parameterType = parameter["type"]?.stringValue ?? ""
        guard parameterType != "choice" else {
            // A choice stands for each of its options, so each one must fit where the reference stands.
            for option in parameter["options"]?.arrayValue ?? [] {
                try check(option, as: type, place: place, kind: kind, scope: &scope)
            }

            return
        }
        guard fits(parameterType, type) else {
            throw ModelError.misplacedParameter(
                place: place,
                kind: kind,
                name: name,
                type: parameterType,
                expected: expectation(of: type)
            )
        }
    }

    private func checkMediaParameter(
        _ object: JSONObject,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws -> MediaKind {
        try checkParameterReference(object, as: .media, place: place, kind: kind, scope: &scope)

        let name = object["param"]?.stringValue ?? ""
        let parameterType = scope.parameters[name]?["type"]?.stringValue ?? ""
        guard let mediaKind = MediaKind(rawValue: parameterType) else {
            throw ModelError.misplacedParameter(
                place: place,
                kind: kind,
                name: name,
                type: parameterType,
                expected: expectation(of: .media)
            )
        }

        return mediaKind
    }

    private func checkFilterOperation(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let object = value.objectValue else { throw wrongType(value, .filterOperation, place, kind) }
        guard let operationValue = object["op"] else {
            throw ModelError.missingKey(place: place, kind: "filter operation", keys: ["op"])
        }
        guard let operation = operationValue.stringValue else {
            throw wrongType(operationValue, .name, place.appending(key: "op"), "filter operation")
        }
        guard FilterKeyTable.operations.contains(operation) else {
            throw ModelError.unknownValue(
                place: place.appending(key: "op"),
                kind: "filter operation",
                value: operation,
                allowed: FilterKeyTable.operations
            )
        }

        try checkObject(object, as: FilterKeyTable.table(for: operation), place: place, scope: &scope)
    }

    private func fits(
        _ parameterType: String,
        _ type: ValueType
    ) -> Bool {
        switch type {
        case let .oneOf(types):
            types.contains { fits(parameterType, $0) }

        case .argument, .anyValue:
            true

        case .media:
            MediaKind(rawValue: parameterType) != nil

        case .text, .area, .crop:
            parameterType == "text"

        case .color:
            parameterType == "color"

        case .number, .integer:
            parameterType == "number"

        default:
            false
        }
    }

    private func takesParameter(_ type: ValueType) -> Bool {
        switch type {
        case .anyObject, .anyValue:
            false

        default:
            true
        }
    }

    private func isDocument(_ value: JSONValue) -> Bool {
        value.objectValue?.contains("kind") ?? false
    }

    private func elementPlace(
        _ place: Place,
        _ index: Int,
        _ element: JSONValue
    ) -> Place {
        place.appending(index: index, id: element.objectValue?["id"]?.stringValue)
    }

    private func admits(
        _ type: ValueType,
        _ value: JSONValue
    ) -> Bool {
        switch (type, value) {
        case (.anyValue, _), (.argument, _), (.oneOf, _):
            true

        case let (.exactly(expected), _):
            expected == value

        case (.bool, .bool):
            true

        case (.number, .number), (.integer, .number):
            true

        case (.text, .string), (.name, .string), (.color, .string), (.hexColor, .string),
             (.identifier, .string), (.literal, .string), (.ease, .string):
            true

        case (.ease, .array), (.numbers, .array), (.list, .array), (.clips, .array), (.operations, .array):
            true

        case (.anyObject, .object), (.map, .object), (.object, .object), (.parameters, .object),
             (.filterOperation, .object), (.document, .object):
            true

        case (.area, .array), (.area, .string), (.area, .object), (.crop, .array), (.crop, .string), (.crop, .object):
            true

        case (.media, .string), (.media, .object):
            true

        default:
            false
        }
    }

    private func wrongType(
        _ value: JSONValue,
        _ type: ValueType,
        _ place: Place,
        _ kind: String
    ) -> ModelError {
        .wrongType(place: place, kind: kind, expected: expectation(of: type), found: finding(of: value))
    }

    private func expectation(of type: ValueType) -> String {
        switch type {
        case .anyValue, .argument:
            "any value"

        case .anyObject, .map, .parameters:
            "an object"

        case let .object(table):
            "an object (\(table.kind))"

        case let .exactly(value):
            finding(of: value)

        case .bool:
            "true or false"

        case .number:
            "a number"

        case .integer:
            "a whole number"

        case .text, .name, .identifier:
            "a string"

        case .color, .hexColor:
            "a colour"

        case .ease:
            "an ease name or [x1, y1, x2, y2]"

        case let .literal(names):
            "one of \(names.joined(separator: ", "))"

        case let .numbers(count):
            "a list of \(count) numbers"

        case .list:
            "a list"

        case let .oneOf(types):
            types.map(expectation(of:)).joined(separator: " or ")

        case .area:
            "an area"

        case .crop:
            "an area or {scale}"

        case .media:
            "a media reference"

        case .document:
            "a document"

        case .clips:
            "a list of clips"

        case .operations:
            "a list of operations"

        case .filterOperation:
            "a filter operation"
        }
    }

    private func finding(of value: JSONValue) -> String {
        switch value {
        case .null:
            "null"

        case let .bool(bool):
            "\(bool)"

        case let .number(number):
            number.rounded() == number && abs(number) < 1e15 ? "\(Int(number))" : "\(number)"

        case let .string(string):
            "\"\(string)\""

        case let .array(elements):
            "a list of \(elements.count)"

        case .object:
            "an object"
        }
    }
}
