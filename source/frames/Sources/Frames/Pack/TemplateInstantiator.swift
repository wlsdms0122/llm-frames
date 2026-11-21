//
//  TemplateInstantiator.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Instantiates a template: every reference to a parameter takes its argument or its default, and the template's
// `params` go, so the instance is a document of plain values. The template passed its checks against its parameter
// types, so only the values are checked here: each against its parameter's type, and against every place it fills.
struct TemplateInstantiator: Sendable {
    // MARK: - Property
    private let checker: KeyChecker
    private let filler: ParameterFiller

    // MARK: - Initializer
    init(mediaKinds: any MediaKindProvider) {
        self.checker = KeyChecker(mediaKinds: mediaKinds)
        self.filler = ParameterFiller(checker: checker)
    }

    // MARK: - Public
    // `place` is where the arguments are written: a template instance's `args`, or the top level of an args file.
    func instance(
        of template: Template,
        arguments: JSONObject,
        place: Place
    ) throws -> TemplateInstance {
        let kind = TemplateKeyTable.argumentsKind
        let values = try filler.values(of: arguments, for: template.parameters, place: place, kind: kind)
        for parameter in template.parameters {
            try checkTaken(
                values[parameter.name] ?? .null,
                parameter: parameter,
                in: arguments,
                place: place,
                template: template
            )
        }

        let given = template.references.filter { reference in
            arguments.contains(reference.name)
                && template.parameters.contains { $0.name == reference.name && $0.type.mediaKind != nil }
        }

        return TemplateInstance(
            document: filler.filling(template.document, at: template.references, with: values),
            arguments: given.map { reference in
                ParameterReference(
                    place: Place(components: reference.place.components),
                    name: reference.name,
                    type: reference.type,
                    kind: reference.kind
                )
            },
            values: values
        )
    }

    // MARK: - Private
    // A default was checked against its type with the template, but its media kind is known only once it is probed,
    // and like an argument it meets the places it fills only when it is taken.
    private func checkTaken(
        _ value: JSONValue,
        parameter: Parameter,
        in arguments: JSONObject,
        place: Place,
        template: Template
    ) throws {
        let found = if arguments.contains(parameter.name) {
            try checkKind(
                of: value,
                parameter: parameter,
                place: place.appending(key: parameter.name),
                kind: TemplateKeyTable.argumentsKind
            )
        } else {
            try checkKind(
                of: value,
                parameter: parameter,
                place: template.place.appending(key: "params").appending(key: parameter.name).appending(key: "default"),
                kind: ParameterKeyTable.kind
            )
        }
        try checkPlaces(of: value, parameter: parameter, template: template)
        if found == .page { try checkPageClips(of: parameter, template: template) }
    }

    // The template was checked with the still row for an `image` parameter, so a clip whose media is a page takes the
    // keys of a page only once it is known to be one: no `toneMap`, and a `colorSpace` of the SDR names (FRAMES-17).
    private func checkPageClips(
        of parameter: Parameter,
        template: Template
    ) throws {
        for reference in template.references where reference.name == parameter.name {
            guard
                reference.place.components.last == .key("media"),
                let clipPlace = clipPlace(of: reference.place),
                let clip = value(at: reference.place.components.dropLast(), in: template.document)?.objectValue
            else { continue }
            let place = Place(file: reference.place.file, components: Array(reference.place.components.dropLast()))
            let table = ClipKeyTable.table(for: .media(.page), in: clipPlace)
            guard !clip.contains("toneMap") else {
                throw ModelError.unknownKey(place: place, kind: table.kind, key: "toneMap", allowed: table.keys)
            }
            if let colorSpace = clip["colorSpace"], let rule = table.rule(named: "colorSpace") {
                try checker.check(colorSpace, as: rule.type, place: place.appending(key: "colorSpace"), kind: table.kind)
            }
        }
    }

    // The place of a clip by the list that holds it, from the place of its media.
    private func clipPlace(of mediaPlace: Place) -> ClipPlace? {
        let list = mediaPlace.components.dropLast(2).last?.key
        switch list {
        case "storyline":
            return .storyline

        case "connected":
            return .connected

        case "clips":
            return .sequence

        default:
            return nil
        }
    }

    private func value(
        at components: ArraySlice<PlaceComponent>,
        in value: JSONValue
    ) -> JSONValue? {
        guard let component = components.first else { return value }

        switch (component, value) {
        case let (.key(key), .object(object)):
            return object[key].flatMap { self.value(at: components.dropFirst(), in: $0) }

        case let (.index(index, _), .array(elements)) where elements.indices.contains(index):
            return self.value(at: components.dropFirst(), in: elements[index])

        default:
            return nil
        }
    }

    // A place can take less than its parameter's type, such as whole pixels for a number, so the value is checked
    // as if written at every place its parameter fills. A choice's options and media were checked there with the
    // template.
    private func checkPlaces(
        of value: JSONValue,
        parameter: Parameter,
        template: Template
    ) throws {
        switch parameter.type {
        case .text, .color, .number:
            for reference in template.references where reference.name == parameter.name {
                try checker.check(value, as: reference.type, place: reference.place, kind: reference.kind)
            }

        case .choice, .video, .sequence, .image, .audio:
            return
        }
    }

    // The kind of a media parameter's value, nil for any other parameter.
    private func checkKind(
        of media: JSONValue,
        parameter: Parameter,
        place: Place,
        kind: String
    ) throws -> MediaKind? {
        guard parameter.type.mediaKind != nil else { return nil }

        let found = try checker.mediaKind(of: media, place: place, kind: kind)
        guard parameter.type.takes(found) else {
            throw PackError.argumentOfWrongKind(
                place: place,
                kind: kind,
                name: parameter.name,
                type: parameter.type.rawValue,
                found: found
            )
        }

        return found
    }
}
