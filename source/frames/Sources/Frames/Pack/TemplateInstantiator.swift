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

    // MARK: - Initializer
    init(mediaKinds: any MediaKindProvider) {
        self.checker = KeyChecker(mediaKinds: mediaKinds)
    }

    // MARK: - Public
    // `place` is where the arguments are written: a template instance's `args`, or the top level of an args file.
    func instance(
        of template: Template,
        arguments: JSONObject,
        place: Place
    ) throws -> TemplateInstance {
        let kind = TemplateKeyTable.argumentsKind
        let names = template.parameters.map(\.name)
        for name in arguments.keys where !names.contains(name) {
            throw PackError.unknownArgument(place: place, kind: kind, name: name, allowed: names)
        }

        let values = try template.parameters.reduce(into: [String: JSONValue]()) { values, parameter in
            values[parameter.name] = try value(of: parameter, in: arguments, place: place, template: template)
        }
        let document = template.references.reduce(template.document) { document, reference in
            replacing(at: reference.place.components[...], in: document, with: values[reference.name] ?? .null)
        }
        let given = template.references.filter { reference in
            arguments.contains(reference.name)
                && template.parameters.contains { $0.name == reference.name && $0.type.mediaKind != nil }
        }

        return TemplateInstance(
            document: removingParameters(from: document),
            kind: template.kind,
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
    private func value(
        of parameter: TemplateParameter,
        in arguments: JSONObject,
        place: Place,
        template: Template
    ) throws -> JSONValue {
        if let argument = arguments[parameter.name] {
            let argumentPlace = place.appending(key: parameter.name)
            try check(argument, of: parameter, place: argumentPlace)
            try checkKind(
                of: argument,
                parameter: parameter,
                place: argumentPlace,
                kind: TemplateKeyTable.argumentsKind
            )
            try checkPlaces(of: argument, parameter: parameter, template: template)

            return argument
        }
        guard let defaultValue = parameter.defaultValue else {
            throw PackError.missingArgument(place: place, kind: TemplateKeyTable.argumentsKind, name: parameter.name)
        }

        try checkKind(
            of: defaultValue,
            parameter: parameter,
            place: template.place.appending(key: "params").appending(key: parameter.name).appending(key: "default"),
            kind: TemplateKeyTable.parameter.kind
        )
        try checkPlaces(of: defaultValue, parameter: parameter, template: template)

        return defaultValue
    }

    // A place can take less than its parameter's type, such as whole pixels for a number, so the value is checked
    // as if written at every place its parameter fills. A choice's options and media were checked there with the
    // template.
    private func checkPlaces(
        of value: JSONValue,
        parameter: TemplateParameter,
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

    // An argument that is an object was checked as media where it is written, so only its type is left.
    private func check(
        _ argument: JSONValue,
        of parameter: TemplateParameter,
        place: Place
    ) throws {
        let kind = TemplateKeyTable.argumentsKind

        switch parameter.type {
        case .text:
            try checker.check(argument, as: .text, place: place, kind: kind)

        case .number:
            try checker.check(argument, as: .number, place: place, kind: kind)

        case .color:
            try checker.check(argument, as: .color, place: place, kind: kind)

        case .choice:
            try checker.check(argument, as: .literal(parameter.options), place: place, kind: kind)

        case .video, .sequence, .image, .audio:
            guard argument.objectValue == nil else { return }

            try checker.check(argument, as: .media, place: place, kind: kind)
        }
    }

    private func checkKind(
        of media: JSONValue,
        parameter: TemplateParameter,
        place: Place,
        kind: String
    ) throws {
        guard let type = parameter.type.mediaKind else { return }

        let found = try checker.mediaKind(of: media, place: place, kind: kind)
        guard found == type else {
            throw PackError.argumentOfWrongKind(
                place: place,
                kind: kind,
                name: parameter.name,
                type: parameter.type.rawValue,
                found: found
            )
        }
    }

    private func replacing(
        at components: ArraySlice<PlaceComponent>,
        in value: JSONValue,
        with replacement: JSONValue
    ) -> JSONValue {
        guard let component = components.first else { return replacement }

        switch (component, value) {
        case let (.key(key), .object(object)):
            let member = replacing(at: components.dropFirst(), in: object[key] ?? .null, with: replacement)
            return .object(object.setting(key, to: member))

        case let (.index(index, _), .array(elements)) where elements.indices.contains(index):
            var elements = elements
            elements[index] = replacing(at: components.dropFirst(), in: elements[index], with: replacement)
            return .array(elements)

        default:
            return value
        }
    }

    private func removingParameters(from document: JSONValue) -> JSONValue {
        guard let object = document.objectValue else { return document }

        return .object(JSONObject(members: object.members.filter { $0.key != "params" }))
    }
}
