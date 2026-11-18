//
//  ParameterFiller.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Fills the published parameters of a template or a preset: each takes its argument, of its type, or its default, and
// every reference to it takes that value, so what is left holds plain values.
struct ParameterFiller: Sendable {
    // MARK: - Property
    private let checker: KeyChecker

    // MARK: - Initializer
    init(checker: KeyChecker) {
        self.checker = checker
    }

    // MARK: - Public
    // `place` is where the arguments are written, which `kind` names. A parameter with neither an argument nor a
    // default stops.
    func values(
        of arguments: JSONObject,
        for parameters: [Parameter],
        place: Place,
        kind: String
    ) throws -> [String: JSONValue] {
        let names = parameters.map(\.name)
        for name in arguments.keys where !names.contains(name) {
            throw ParameterError.unknownArgument(place: place, kind: kind, name: name, allowed: names)
        }

        return try parameters.reduce(into: [String: JSONValue]()) { values, parameter in
            if let argument = arguments[parameter.name] {
                try check(argument, of: parameter, place: place.appending(key: parameter.name), kind: kind)
                values[parameter.name] = argument
            } else if let defaultValue = parameter.defaultValue {
                values[parameter.name] = defaultValue
            } else {
                throw ParameterError.missingArgument(place: place, kind: kind, name: parameter.name)
            }
        }
    }

    // The value with every reference replaced by its parameter's value, and its `params` gone.
    func filling(
        _ value: JSONValue,
        at references: [ParameterReference],
        with values: [String: JSONValue]
    ) -> JSONValue {
        let filled = references.reduce(value) { filled, reference in
            replacing(at: reference.place.components[...], in: filled, with: values[reference.name] ?? .null)
        }
        guard let object = filled.objectValue else { return filled }

        return .object(JSONObject(members: object.members.filter { $0.key != "params" }))
    }

    // MARK: - Private
    // Media written as an object was checked where it is written, so only its kind is left, which the caller probes.
    private func check(
        _ argument: JSONValue,
        of parameter: Parameter,
        place: Place,
        kind: String
    ) throws {
        guard parameter.type.mediaKind == nil || !TemplateKeyTable.isMedia(argument) else { return }

        try checker.check(argument, as: parameter.valueType, place: place, kind: kind)
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
}
