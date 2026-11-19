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
    func check(
        document: JSONValue,
        place: Place = .root
    ) throws {
        _ = try check(template: document, place: place)
    }

    // A document checked as a template, with the place of every parameter reference in it, so they can be filled.
    func check(
        template: JSONValue,
        place: Place
    ) throws -> [ParameterReference] {
        var scope = DocumentScope()
        try checkDocument(
            template,
            place: place,
            kind: "document",
            isNested: false,
            scope: &scope
        )

        return scope.references
    }

    // A preset checked against its parameter types, with the place of every reference to a parameter in it, so they
    // can be filled.
    func check(
        preset: JSONValue,
        as table: ObjectTable,
        place: Place
    ) throws -> [ParameterReference] {
        guard let object = preset.objectValue else { throw wrongType(preset, .object(table), place, table.kind) }

        var scope = DocumentScope(owner: .preset)
        try checkPublishing(object, as: table, place: place, scope: &scope)

        return scope.references
    }

    // The `params` a template declares, checked as they are where they are written and without the rest of it, so
    // what it publishes can be read while what it holds, its media included, is not.
    func check(
        declarationsOf template: JSONValue,
        place: Place
    ) throws {
        let table = DocumentKeyTable.sequence
        guard let object = template.objectValue else { throw wrongType(template, .document, place, "document") }

        var scope = DocumentScope()
        try checkDeclarations(of: object, as: table, place: place, scope: &scope)
    }

    // A document named by its file where media is taken, which stands as if written there.
    func check(
        nestedDocument document: JSONValue,
        place: Place
    ) throws {
        var scope = DocumentScope()
        try checkDocument(
            document,
            place: place,
            kind: "document",
            isNested: true,
            scope: &scope
        )
    }

    func check(
        _ value: JSONValue,
        as table: ObjectTable,
        place: Place = .root
    ) throws {
        try check(value, as: .object(table), place: place, kind: table.kind)
    }

    func check(
        _ value: JSONValue,
        as type: ValueType,
        place: Place,
        kind: String
    ) throws {
        var scope = DocumentScope()
        try check(
            value,
            as: type,
            place: place,
            kind: kind,
            scope: &scope
        )
    }

    // The kind of media that passed the checks, as its probe or its form gives it.
    func mediaKind(
        of media: JSONValue,
        place: Place,
        kind: String
    ) throws -> MediaKind {
        try mediaKind(of: media, place: place, kind: kind, scope: DocumentScope())
    }

    // MARK: - Private
    private func check(
        _ value: JSONValue,
        as type: ValueType,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        if case let .object(object) = value, object.contains("param"), takesParameter(type, by: scope.owner) {
            try checkParameterReference(object, as: type, place: place, kind: kind, scope: &scope)
            return
        }

        switch type {
        case .anyValue, .presetArgument:
            return

        case .argument:
            // An argument's type is the template's to say, and only media is checked where it is written.
            guard MediaKeyTable.isMedia(value) else { return }

            try checkMedia(value, place: place, kind: kind, scope: &scope)

        case let .exactly(expected):
            guard value == expected else { throw wrongType(value, type, place, kind) }

        case .anyObject, .bool, .number, .text, .name:
            guard admits(type, value) else { throw wrongType(value, type, place, kind) }

        case .positiveNumber:
            guard let number = value.numberValue, number > 0 else { throw wrongType(value, type, place, kind) }

        case .nonNegativeNumber:
            guard let number = value.numberValue, number >= 0 else { throw wrongType(value, type, place, kind) }

        case .fraction:
            guard let number = value.numberValue, (0...1).contains(number) else { throw wrongType(value, type, place, kind) }

        case .signedFraction:
            guard let number = value.numberValue, (-1...1).contains(number) else {
                throw wrongType(value, type, place, kind)
            }

        case .openSignedFraction:
            guard let number = value.numberValue, number > -1, number < 1 else {
                throw wrongType(value, type, place, kind)
            }

        case .integer:
            // A whole number that does not fit an integer could not be read as one.
            guard let number = value.numberValue, Int(exactly: number) != nil else {
                throw wrongType(value, type, place, kind)
            }

        case .nonNegativeInteger:
            guard let number = value.numberValue, let integer = Int(exactly: number), integer >= 0 else {
                throw wrongType(value, type, place, kind)
            }

        case .positiveInteger:
            guard let number = value.numberValue, let integer = Int(exactly: number), integer > 0 else {
                throw wrongType(value, type, place, kind)
            }

        case .color, .hexColor:
            try checkColor(value, as: type, place: place, kind: kind)

        case .identifier:
            try checkIdentifier(value, place: place, kind: kind, scope: &scope)

        case .ease:
            try checkEase(value, place: place, kind: kind, scope: &scope)

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

        case let .fractions(count):
            guard let elements = value.arrayValue, elements.count == count else {
                throw wrongType(value, type, place, kind)
            }

            for (index, element) in elements.enumerated() {
                guard let number = element.numberValue, (0...1).contains(number) else {
                    throw wrongType(element, type, place.appending(index: index), kind)
                }
            }

        case .points:
            guard let elements = value.arrayValue, elements.count >= 2 else {
                throw wrongType(value, type, place, kind)
            }

            for (index, element) in elements.enumerated() {
                try check(element, as: AreaKeyTable.point, place: place.appending(index: index), kind: kind, scope: &scope)
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
            try checkArea(value, as: type, place: place, kind: kind, scope: &scope)

        case .crop:
            if case let .object(object) = value, object.contains("scale") {
                try checkObject(object, as: AreaKeyTable.cropScale, place: place, scope: &scope)
            } else {
                try checkArea(value, as: type, place: place, kind: kind, scope: &scope)
            }

        case .margin:
            try checkMargin(value, place: place, kind: kind, scope: &scope)

        case .masks:
            try checkMasks(value, place: place, kind: kind, scope: &scope)

        case .runs:
            try checkRuns(value, place: place, kind: kind, scope: &scope)

        case .media:
            try checkMedia(value, place: place, kind: kind, scope: &scope)

        case .document:
            try checkDocument(value, place: place, kind: kind, isNested: true, scope: &scope)

        case let .clips(clipPlace):
            guard let elements = value.arrayValue else { throw wrongType(value, type, place, kind) }
            for (index, element) in elements.enumerated() {
                try checkClip(element, place: elementPlace(place, index, element), in: clipPlace, scope: &scope)
            }

        case let .parameters(table):
            guard let object = value.objectValue else { throw wrongType(value, type, place, kind) }
            for member in object.members {
                try checkParameter(
                    member.value,
                    named: member.key,
                    as: table,
                    place: place.appending(key: member.key),
                    scope: &scope
                )
            }

        case .filterOperation:
            try checkFilterOperation(value, place: place, kind: kind, scope: &scope)

        case .filterChoice:
            try checkFilterChoice(value, place: place, kind: kind, scope: &scope)

        case .audioFilterChoice:
            try checkAudioFilterChoice(value, place: place, kind: kind, scope: &scope)
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
        // Objects of several forms are told apart by the keys they hold.
        var admitting = types.indices.filter { admits(types[$0], value) }
        if admitting.count > 1, let object = value.objectValue {
            admitting = admitting.filter { index in
                guard case let .object(table) = types[index] else { return false }

                return object.keys.contains { table.rule(named: $0) != nil }
            }
        }
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
        kind: String,
        scope: inout DocumentScope
    ) throws {
        switch value {
        case let .string(name):
            guard VocabularyTable.easeNames.contains(name) else {
                throw ModelError.unknownValue(
                    place: place,
                    kind: kind,
                    value: name,
                    allowed: VocabularyTable.easeNames + ["[x1, y1, x2, y2]", "{spring}"]
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

        case let .object(object):
            try checkObject(object, as: EaseKeyTable.spring, place: place, scope: &scope)

        default:
            throw wrongType(value, .ease, place, kind)
        }
    }

    // A rectangle's width and height are above 0. `type` is the area or crop being checked, which a message names.
    private func checkArea(
        _ value: JSONValue,
        as type: ValueType,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        switch value {
        case let .array(elements):
            guard elements.count == 4 else { throw wrongType(value, type, place, kind) }

            for (index, element) in elements.enumerated() {
                let elementType: ValueType = index < 2 ? .number : .positiveNumber
                try check(element, as: elementType, place: place.appending(index: index), kind: kind, scope: &scope)
            }

        case let .object(object):
            if object.contains("text") {
                try checkObject(object, as: AreaKeyTable.text, place: place, scope: &scope)
            } else if object.contains("from") || object.contains("to") {
                try checkObject(object, as: AreaKeyTable.range, place: place, scope: &scope)
            } else {
                throw ModelError.missingKey(place: place, kind: "area", keys: ["text", "from"])
            }

        default:
            throw wrongType(value, type, place, kind)
        }
    }

    // An empty list stops, since a clip without masks writes no `mask`.
    private func checkMasks(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let elements = value.arrayValue else {
            try checkMask(value, place: place, kind: kind, scope: &scope)
            return
        }
        guard !elements.isEmpty else {
            throw ModelError.invalidValue(
                place: place,
                kind: kind,
                reason: "a mask list holds at least one mask, and a clip without masks writes no mask"
            )
        }

        for (index, element) in elements.enumerated() {
            try checkMask(element, place: place.appending(index: index), kind: kind, scope: &scope)
        }
    }

    // An empty list stops, since it is a title with nothing to show.
    private func checkRuns(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let elements = value.arrayValue else {
            try check(value, as: .text, place: place, kind: kind, scope: &scope)
            return
        }
        guard !elements.isEmpty else {
            throw ModelError.invalidValue(
                place: place,
                kind: kind,
                reason: "a list of runs holds at least one run, since a title without one has nothing to show"
            )
        }

        for (index, element) in elements.enumerated() {
            let place = place.appending(index: index)
            try check(element, as: .object(ClipKeyTable.run), place: place, kind: kind, scope: &scope)
        }
    }

    // A mask is checked as each shape its `shape` can be.
    private func checkMask(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let object = value.objectValue else { throw wrongType(value, .masks, place, kind) }
        guard object.contains("shape") else { throw ModelError.missingKey(place: place, kind: "mask", keys: ["shape"]) }

        let shapes = try shapes(of: object, place: place, kind: "mask", scope: &scope)
        try checkEach(shapes, scope: &scope) { shape, scope in
            try checkMask(object, as: shape, place: place, scope: &scope)
        }
    }

    // A mask takes the keys of its shape. A rect or an ellipse takes exactly one of `area` and the box `width`,
    // `height` and `position`, all three together, and a path at least three points, since its path is closed.
    private func checkMask(
        _ object: JSONObject,
        as shape: ShapeKind,
        place: Place,
        scope: inout DocumentScope
    ) throws {
        let table = MaskKeyTable.table(for: shape)
        if shape == .path, let points = object["points"]?.arrayValue, points.count < 3 {
            throw ModelError.invalidValue(
                place: place.appending(key: "points"),
                kind: table.kind,
                reason: "a path mask is closed, so it runs through at least three points, found \(points.count)"
            )
        }
        try checkObject(object, as: table, place: place, skipping: ["shape"], scope: &scope)
        guard shape != .path else { return }

        let box = MaskKeyTable.box.filter(object.contains)
        if object.contains("area") {
            guard box.isEmpty else {
                throw ModelError.conflictingKeys(place: place, kind: table.kind, keys: ["area"] + box)
            }
        } else if box.isEmpty {
            throw ModelError.missingKey(place: place, kind: table.kind, keys: ["area"] + MaskKeyTable.box)
        } else if let missing = MaskKeyTable.box.first(where: { !object.contains($0) }) {
            throw ModelError.missingKey(place: place, kind: table.kind, keys: [missing])
        }
    }

    // `n`, `[v, h]` or `[t, r, b, l]`, each a whole number 0 or more.
    private func checkMargin(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        switch value {
        case .number:
            try check(value, as: .nonNegativeInteger, place: place, kind: kind, scope: &scope)

        case let .array(elements):
            guard elements.count == 2 || elements.count == 4 else { throw wrongType(value, .margin, place, kind) }

            for (index, element) in elements.enumerated() {
                let side = place.appending(index: index)
                try check(element, as: .nonNegativeInteger, place: side, kind: kind, scope: &scope)
            }

        default:
            throw wrongType(value, .margin, place, kind)
        }
    }

    private func checkMedia(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        switch value {
        case .string:
            return

        case let .object(object) where object.contains("param"):
            try checkParameterReference(object, as: .media, place: place, kind: kind, scope: &scope)
            _ = try parameterKind(of: object, place: place, kind: kind, scope: scope)

        case let .object(object) where object.contains("kind"):
            try checkDocument(value, place: place, kind: kind, isNested: true, scope: &scope)

        case let .object(object) where object.contains("imageSequence"):
            try checkObject(object, as: MediaKeyTable.imageSequence, place: place, scope: &scope)

        case let .object(object) where object.contains("template"):
            try checkObject(object, as: TemplateKeyTable.instance, place: place, scope: &scope)

        case .object:
            throw ModelError.missingKey(place: place, kind: "media", keys: MediaKeyTable.keys)

        default:
            throw wrongType(value, .media, place, kind)
        }
    }

    private func probeMedia(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws -> MediaKind {
        try checkMedia(value, place: place, kind: kind, scope: &scope)

        return try mediaKind(of: value, place: place, kind: kind, scope: scope)
    }

    private func mediaKind(
        of value: JSONValue,
        place: Place,
        kind: String,
        scope: DocumentScope
    ) throws -> MediaKind {
        switch value {
        case let .string(reference):
            return try probedKind(of: reference, place: place, kind: kind)

        case let .object(object) where object.contains("param"):
            return try parameterKind(of: object, place: place, kind: kind, scope: scope)

        case let .object(object) where object.contains("kind"):
            return .sequence

        case let .object(object) where object.contains("template"):
            return try templateKind(of: object["template"] ?? .null, place: place, kind: kind, scope: scope)

        default:
            // The shape check lets nothing else through than an image sequence.
            return .video
        }
    }

    // Every template is a sequence, so an instance is a compound clip once the templates it may name are there. The
    // shape check lets only a choice name a template, and it may name any of its options.
    private func templateKind(
        of template: JSONValue,
        place: Place,
        kind: String,
        scope: DocumentScope
    ) throws -> MediaKind {
        let names: [String] = if case let .object(reference) = template {
            scope.parameters[reference["param"]?.stringValue ?? ""]?["options"]?.arrayValue?.compactMap(\.stringValue)
                ?? []
        } else {
            [template.stringValue ?? ""]
        }
        for name in names where try !mediaKinds.hasTemplate(named: name) {
            throw ModelError.unknownTemplate(place: place.appending(key: "template"), kind: kind, name: name)
        }

        return .sequence
    }

    private func probedKind(
        of reference: String,
        place: Place,
        kind: String
    ) throws -> MediaKind {
        let probed: MediaKind?
        do {
            probed = try mediaKinds.mediaKind(of: reference)
        } catch let error as UnreadableMediaError {
            throw ModelError.unreadableMedia(place: place, kind: kind, reference: reference, reason: "\(error.reason)")
        }
        guard let probed else {
            throw ModelError.missingMedia(place: place, kind: kind, reference: reference)
        }

        return probed
    }

    private func checkDocument(
        _ value: JSONValue,
        place: Place,
        kind: String,
        isNested: Bool,
        scope: inout DocumentScope
    ) throws {
        guard let object = value.objectValue else { throw wrongType(value, .document, place, kind) }
        guard let kindValue = object["kind"] else {
            throw ModelError.missingKey(place: place, kind: kind, keys: ["kind"])
        }
        guard let documentKind = kindValue.stringValue else {
            throw wrongType(kindValue, .text, place.appending(key: "kind"), "document")
        }
        let table = DocumentKeyTable.sequence
        guard documentKind == table.kind else {
            throw ModelError.unknownValue(
                place: place.appending(key: "kind"),
                kind: "document",
                value: documentKind,
                allowed: [table.kind]
            )
        }

        guard !isNested else {
            guard !object.contains("params") else {
                throw ModelError.nestedTemplate(place: place, kind: table.kind)
            }

            // A nested document has ids of its own, while a template's parameters reach into it.
            let outerIdentifiers = scope.identifiers
            scope.identifiers = [:]
            try checkObject(object, as: table, place: place, scope: &scope)
            scope.identifiers = outerIdentifiers
            return
        }

        try checkPublishing(object, as: table, place: place, scope: &scope)
    }

    // An object that may publish `params`, a template or a preset, whose references name its own parameters.
    private func checkPublishing(
        _ object: JSONObject,
        as table: ObjectTable,
        place: Place,
        scope: inout DocumentScope
    ) throws {
        // Declarations are checked before anything refers to them, so a broken one is reported where it is written,
        // and a reference written before `params` still finds its declaration.
        try checkDeclarations(of: object, as: table, place: place, scope: &scope)
        try checkObject(object, as: table, place: place, skipping: ["params"], scope: &scope)

        let parameters = object["params"]?.objectValue?.members ?? []

        for member in parameters where !scope.usedParameters.contains(member.key) {
            throw ModelError.unusedParameter(place: place.appending(key: "params").appending(key: member.key), name: member.key)
        }
    }

    // The `params` an object publishes, each checked by its owner's table, and known to the scope by name.
    private func checkDeclarations(
        of object: JSONObject,
        as table: ObjectTable,
        place: Place,
        scope: inout DocumentScope
    ) throws {
        guard let declarations = object["params"], let rule = table.rule(named: "params") else { return }

        try check(declarations, as: rule.type, place: place.appending(key: "params"), kind: table.kind, scope: &scope)
        scope.parameters = Dictionary(
            (declarations.objectValue?.members ?? []).compactMap { member in
                member.value.objectValue.map { (member.key, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func checkClip(
        _ value: JSONValue,
        place: Place,
        in clipPlace: ClipPlace,
        scope: inout DocumentScope
    ) throws {
        let generic = clipPlace.label
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

        let clipKinds = try clipKinds(of: object, by: present[0], place: place, in: clipPlace, scope: &scope)
        try checkEach(clipKinds, scope: &scope) { clipKind, scope in
            let takesSound = clipPlace != .storyline && object["picture"] == .bool(false)
                && (clipKind == .media(.video) || clipKind == .media(.sequence))
            let table = if takesSound, case let .media(media) = clipKind {
                ClipKeyTable.soundTable(of: media, in: clipPlace)
            } else {
                ClipKeyTable.table(for: clipKind, in: clipPlace)
            }
            let checkedKind = takesSound ? ClipKind.media(.audio) : clipKind
            try checkKeyframedOnly(object, kind: checkedKind, place: place, in: clipPlace)
            try checkObject(object, as: table, place: place, skipping: ["media", "shape"], scope: &scope)
            try checkStaticAndKeyframed(object, kind: checkedKind, place: place, in: clipPlace)
        }

        if let keyframes = object["keyframes"] {
            try keyframeReader.checkEases(in: keyframes, place: place.appending(key: "keyframes"))
        }
    }

    // A clip is of one kind, or of one for each option of a choice its shape takes.
    private func clipKinds(
        of object: JSONObject,
        by key: String,
        place: Place,
        in clipPlace: ClipPlace,
        scope: inout DocumentScope
    ) throws -> [ClipKind] {
        let generic = clipPlace.label

        switch key {
        case "media":
            let mediaKind = try probeMedia(
                object["media"] ?? .null,
                place: place.appending(key: "media"),
                kind: generic,
                scope: &scope
            )
            guard clipPlace != .storyline || mediaKind != .audio else {
                throw ModelError.misplacedMedia(
                    place: place,
                    kind: ClipKind.media(.audio).label,
                    reason: "a storyline clip needs a picture, and this media holds only sound"
                )
            }

            return [.media(mediaKind)]

        case "shape":
            return try shapes(of: object, place: place, kind: "shape", scope: &scope).map { .shape($0.rawValue) }

        case "title":
            return [.title]

        case "adjust":
            return [.adjust]

        default:
            return [.solid]
        }
    }

    // A property the clip takes only in keyframes stops as a static value, not as a key the clip does not know.
    private func checkKeyframedOnly(
        _ object: JSONObject,
        kind: ClipKind,
        place: Place,
        in clipPlace: ClipPlace
    ) throws {
        let keyframable = ClipKeyTable.keyframable(for: kind, in: clipPlace)
        for property in ClipKeyTable.keyframedOnly where keyframable.contains(property) && object.contains(property) {
            throw ModelError.staticKeyframedOnly(
                place: place.appending(key: property),
                kind: kind.label,
                property: property
            )
        }
    }

    private func checkStaticAndKeyframed(
        _ object: JSONObject,
        kind: ClipKind,
        place: Place,
        in clipPlace: ClipPlace
    ) throws {
        guard let keyframes = object["keyframes"]?.arrayValue else { return }

        let properties = ClipKeyTable.keyframable(for: kind, in: clipPlace).filter { !ClipKeyTable.lookKeys.contains($0) }
        for keyframe in keyframes.compactMap(\.objectValue) {
            for property in properties where keyframe.contains(property) && object.contains(property) {
                throw ModelError.staticAndKeyframed(place: place, kind: kind.label, property: property)
            }
        }
    }

    // A shape picks the keys its object takes, a clip's or a mask's, so a choice there stands for each of its options.
    private func shapes(
        of object: JSONObject,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws -> [ShapeKind] {
        let value = object["shape"] ?? .null
        try check(
            value,
            as: .literal(VocabularyTable.shapes),
            place: place.appending(key: "shape"),
            kind: kind,
            scope: &scope
        )

        // A reference passes the check only as a choice, whose options are the shapes it stands for.
        let name = value.objectValue?["param"]?.stringValue
        let written = name.map { scope.parameters[$0]?["options"]?.arrayValue ?? [] } ?? [value]

        return written.compactMap { $0.stringValue.flatMap(ShapeKind.init(rawValue:)) }
    }

    // Checks the same object once for each kind it can be, as if written with that kind, and takes the references
    // and ids it holds once.
    private func checkEach<Kind>(
        _ kinds: [Kind],
        scope: inout DocumentScope,
        checking check: (Kind, inout DocumentScope) throws -> Void
    ) throws {
        let written = scope
        for (index, kind) in kinds.enumerated() {
            var trial = written
            try check(kind, &trial)
            guard index == 0 else { continue }

            scope = trial
        }
    }

    private func checkParameter(
        _ value: JSONValue,
        named name: String,
        as table: ObjectTable,
        place: Place,
        scope: inout DocumentScope
    ) throws {
        guard let object = value.objectValue else { throw wrongType(value, .object(table), place, table.kind) }

        try checkObject(object, as: table, place: place, skipping: ["default"], scope: &scope)

        let isChoice = object["type"]?.stringValue == ParameterType.choice.rawValue
        if isChoice, !object.contains("options") {
            throw ModelError.missingKey(place: place, kind: table.kind, keys: ["options"])
        }
        if isChoice, let options = object["options"]?.arrayValue, distinctCount(of: options) < 2 {
            throw ModelError.invalidValue(
                place: place.appending(key: "options"),
                kind: table.kind,
                reason: "a choice offers at least two distinct options"
            )
        }
        if !isChoice, object.contains("options") {
            throw ModelError.unknownKey(
                place: place,
                kind: table.kind,
                key: "options",
                allowed: table.keys.filter { $0 != "options" }
            )
        }

        guard let defaultValue = object["default"], let parameter = Parameter(name: name, declaration: object) else { return }

        var defaultScope = scope
        try check(
            defaultValue,
            as: parameter.valueType,
            place: place.appending(key: "default"),
            kind: table.kind,
            scope: &defaultScope
        )
    }

    private func distinctCount(of values: [JSONValue]) -> Int {
        values.indices.filter { index in !values[..<index].contains(values[index]) }.count
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
        scope.references.append(ParameterReference(place: place, name: name, type: type, kind: kind))

        let parameterType = parameter["type"]?.stringValue ?? ""
        if parameterType == ParameterType.choice.rawValue, scope.owner == .preset, type != .ease {
            throw ModelError.misplacedParameter(
                place: place,
                kind: kind,
                name: name,
                type: parameterType,
                expected: expectation(of: type)
            )
        }
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

    private func parameterKind(
        of object: JSONObject,
        place: Place,
        kind: String,
        scope: DocumentScope
    ) throws -> MediaKind {
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

    // `"none"` turns the filter off, so it is written alone, and a list applies at least one entry. An object naming
    // `op` is an op written in place, which takes `mix` beside its parameters.
    private func checkFilterChoice(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let elements = value.arrayValue else {
            try checkFilterEntry(value, place: place, kind: kind, scope: &scope)
            return
        }
        guard !elements.isEmpty else {
            throw ModelError.invalidValue(
                place: place,
                kind: ChoiceKeyTable.filterKind,
                reason: "a filter list holds at least one entry"
            )
        }

        for (index, element) in elements.enumerated() {
            let elementPlace = place.appending(index: index)
            guard element != .string("none") else {
                throw ModelError.invalidValue(
                    place: elementPlace,
                    kind: ChoiceKeyTable.filterKind,
                    reason: "\"none\" turns the filter off, so it is written alone and never in a list"
                )
            }

            try checkFilterEntry(element, place: elementPlace, kind: kind, scope: &scope)
        }
    }

    private func checkFilterEntry(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let object = value.objectValue, object.contains("op") else {
            try check(value, as: ChoiceKeyTable.filterPreset, place: place, kind: kind, scope: &scope)
            return
        }

        let operation = JSONObject(members: object.members.filter { $0.key != "mix" })
        try checkFilterOperation(.object(operation), place: place, kind: kind, scope: &scope)
        if let mix = object["mix"] {
            try check(mix, as: .fraction, place: place.appending(key: "mix"), kind: ChoiceKeyTable.filterKind, scope: &scope)
        }
    }

    // A list applies at least one entry. An object naming `op` is an op written in place, which takes `mix` beside
    // its parameters, and an `eq` holds at least one band, each taking the keys of its `type`.
    private func checkAudioFilterChoice(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let elements = value.arrayValue else {
            try checkAudioFilterEntry(value, place: place, kind: kind, scope: &scope)
            return
        }
        guard !elements.isEmpty else {
            throw ModelError.invalidValue(
                place: place,
                kind: AudioFilterKeyTable.kind,
                reason: "an audio filter list holds at least one entry"
            )
        }

        for (index, element) in elements.enumerated() {
            try checkAudioFilterEntry(element, place: place.appending(index: index), kind: kind, scope: &scope)
        }
    }

    private func checkAudioFilterEntry(
        _ value: JSONValue,
        place: Place,
        kind: String,
        scope: inout DocumentScope
    ) throws {
        guard let object = value.objectValue, let operationValue = object["op"] else {
            try check(value, as: ChoiceKeyTable.audioFilterPreset, place: place, kind: kind, scope: &scope)
            return
        }
        guard let operation = operationValue.stringValue else {
            throw wrongType(operationValue, .name, place.appending(key: "op"), "audio operation")
        }
        guard AudioFilterKeyTable.operations.contains(operation) else {
            throw ModelError.unknownValue(
                place: place.appending(key: "op"),
                kind: "audio operation",
                value: operation,
                allowed: AudioFilterKeyTable.operations
            )
        }

        let parameters = JSONObject(members: object.members.filter { $0.key != "mix" })
        try checkObject(parameters, as: AudioFilterKeyTable.table(for: operation), place: place, scope: &scope)
        if let mix = object["mix"] {
            let mixPlace = place.appending(key: "mix")
            try check(mix, as: .fraction, place: mixPlace, kind: AudioFilterKeyTable.kind, scope: &scope)
        }

        let bands = object["bands"]?.arrayValue ?? []
        guard operation == "eq" else { return }
        guard !bands.isEmpty else {
            throw ModelError.invalidValue(
                place: place.appending(key: "bands"),
                kind: operation,
                reason: "an eq holds at least one band"
            )
        }

        for (index, band) in bands.enumerated() {
            let bandPlace = place.appending(key: "bands").appending(index: index)
            let bandObject = band.objectValue ?? JSONObject()
            guard let type = bandObject["type"] else {
                throw ModelError.missingKey(place: bandPlace, kind: "band", keys: ["type"])
            }

            let types = ValueType.literal(AudioFilterKeyTable.bandTypes)
            try check(type, as: types, place: bandPlace.appending(key: "type"), kind: "band", scope: &scope)
            try checkObject(
                bandObject,
                as: AudioFilterKeyTable.band(of: type.stringValue ?? ""),
                place: bandPlace,
                scope: &scope
            )
        }
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

        case .presetArgument:
            parameterType == "number" || parameterType == "color"

        case .media:
            MediaKind(rawValue: parameterType) != nil

        case .text, .runs:
            parameterType == "text"

        case .color:
            parameterType == "color"

        case .number, .positiveNumber, .nonNegativeNumber, .fraction, .signedFraction, .openSignedFraction, .integer,
             .nonNegativeInteger, .positiveInteger, .margin:
            parameterType == "number"

        default:
            false
        }
    }

    // A preset's parameter never stands for a name, a key or a file, only where a number, a colour or an ease is written.
    private func takesParameter(
        _ type: ValueType,
        by owner: ParameterOwner
    ) -> Bool {
        switch (owner, type) {
        case (_, .anyObject), (_, .anyValue):
            false

        case (.template, _):
            true

        case (.preset, _):
            type == .ease || fits("number", type) || fits("color", type)
        }
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
        case (.anyValue, _), (.argument, _), (.presetArgument, _), (.oneOf, _):
            true

        case let (.exactly(expected), _):
            expected == value

        case (.bool, .bool):
            true

        case (.number, .number), (.positiveNumber, .number), (.nonNegativeNumber, .number), (.fraction, .number),
             (.signedFraction, .number),
             (.openSignedFraction, .number), (.integer, .number), (.nonNegativeInteger, .number), (.positiveInteger, .number):
            true

        case (.text, .string), (.name, .string), (.color, .string), (.hexColor, .string),
             (.identifier, .string), (.literal, .string), (.ease, .string):
            true

        case (.ease, .array), (.ease, .object), (.numbers, .array), (.fractions, .array), (.points, .array), (.list, .array),
             (.clips, .array):
            true

        case (.anyObject, .object), (.map, .object), (.object, .object), (.parameters, .object),
             (.filterOperation, .object), (.document, .object):
            true

        case (.area, .array), (.area, .object), (.crop, .array), (.crop, .object), (.margin, .number), (.margin, .array):
            true

        case (.media, .string), (.media, .object), (.masks, .object), (.masks, .array), (.runs, .string),
             (.runs, .array):
            true

        case (.filterChoice, .string), (.filterChoice, .object), (.filterChoice, .array),
             (.audioFilterChoice, .string), (.audioFilterChoice, .object), (.audioFilterChoice, .array):
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

        case .positiveNumber:
            "a number above 0"

        case .nonNegativeNumber:
            "a number, 0 or more"

        case .fraction:
            "a number from 0 to 1"

        case .signedFraction:
            "a number from -1 to 1"

        case .openSignedFraction:
            "a number greater than -1 and less than 1"

        case .integer:
            "a whole number"

        case .nonNegativeInteger:
            "a whole number, 0 or more"

        case .positiveInteger:
            "a whole number, 1 or more"

        case .text, .name, .identifier:
            "a string"

        case .color, .hexColor:
            "a colour"

        case .ease:
            "an ease name, [x1, y1, x2, y2] or {spring}"

        case let .literal(names):
            "one of \(names.joined(separator: ", "))"

        case let .numbers(count):
            "a list of \(count) numbers"

        case let .fractions(count):
            "a list of \(count) numbers, each from 0 to 1"

        case .points:
            "a list of at least two points"

        case .list:
            "a list"

        case let .oneOf(types):
            types.map(expectation(of:)).joined(separator: " or ")

        case .area:
            "an area"

        case .crop:
            "an area or {scale}"

        case .margin:
            "a whole number, 0 or more, or a list of 2 or 4 of them"

        case .masks:
            "a mask or a list of masks"

        case .runs:
            "a string or a list of runs"

        case .media:
            "a media reference"

        case .document:
            "a document"

        case .clips:
            "a list of clips"

        case .filterOperation:
            "a filter operation"

        case .presetArgument:
            "a number, a colour or an ease"

        case .filterChoice:
            "a preset name, {preset, args} or a list of them"

        case .audioFilterChoice:
            "an audio preset name, {preset, args, mix}, an audio op or a list of them"
        }
    }

    private func finding(of value: JSONValue) -> String {
        switch value {
        case let .array(elements):
            "a list of \(elements.count)"

        case .object:
            "an object"

        default:
            value.written
        }
    }
}
