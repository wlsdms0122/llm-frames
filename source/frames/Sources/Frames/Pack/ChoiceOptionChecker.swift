//
//  ChoiceOptionChecker.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Checks every option of a template's choices as resolve checks a name written where the choice stands: a preset is
// there and the arguments beside it fit its parameters, and a theme, text style, shape style or theme colour is there.
// Each option is tried with every other parameter at its default. A reference to a parameter without one stays a
// reference: an argument it stands for is left out of a preset's arguments, and a theme it stands for leaves the names
// under it to each instance.
struct ChoiceOptionChecker: Sendable {
    // MARK: - Property
    private let presets: any PresetProvider
    private let library: ReferenceLibrary
    private let themes: DocumentThemeResolver
    private let filler = ParameterFiller(checker: KeyChecker())

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.presets = presets
        self.library = library
        self.themes = DocumentThemeResolver(library: library)
    }

    // MARK: - Public
    func check(_ template: Template) throws {
        let defaults = template.parameters.reduce(into: [String: JSONValue]()) { values, parameter in
            values[parameter.name] = parameter.defaultValue
        }

        for reference in template.references {
            guard
                let parameter = template.parameters.first(where: { $0.name == reference.name }),
                parameter.type == .choice,
                let target = ChoiceTarget(reference: reference)
            else {
                continue
            }

            for option in parameter.options {
                var values = defaults
                values[parameter.name] = option
                let filled = filler.filling(
                    template.document,
                    at: template.references.filter { values[$0.name] != nil },
                    with: values
                )

                try check(
                    option,
                    of: parameter,
                    as: target,
                    at: reference,
                    in: filled
                )
            }
        }
    }

    // MARK: - Private
    private func check(
        _ option: JSONValue,
        of parameter: Parameter,
        as target: ChoiceTarget,
        at reference: ParameterReference,
        in document: JSONValue
    ) throws {
        switch target {
        case let .preset(kind, choice, part):
            let place = Place(file: reference.place.file, components: choice)
            let missing = try missingPreset(in: value(at: choice[...], in: document), kind: kind, place: place)
            // An argument is not what names the preset, so a preset that is not there is resolve's to stop on.
            guard let missing, part != .argument else { return }

            throw stop(option, of: parameter, at: reference, naming: try presets.unknown(kind, named: missing))

        case .theme:
            guard let name = option.stringValue, try library.theme(named: name) == nil else { return }

            throw stop(option, of: parameter, at: reference, naming: try library.unknown(.theme, named: name))

        case .textStyle, .shapeStyle, .color:
            guard
                let name = option.stringValue,
                let theme = try theme(
                    at: reference.place.components[...],
                    in: document,
                    place: Place(file: reference.place.file, components: []),
                    over: .base
                )
            else {
                return
            }

            let isThere = switch target {
            case .textStyle:
                theme.styleNames.contains(name)

            case .shapeStyle:
                theme.shapeStyle(named: name) != nil

            default:
                theme.isColor(name)
            }
            guard !isThere else { return }

            throw PackError.unknownOption(
                place: reference.place,
                kind: reference.kind,
                name: parameter.name,
                option: option,
                target: target.label
            )
        }
    }

    // The stop for `option` of `parameter`, which names something a pack holds that is not there.
    private func stop(
        _ option: JSONValue,
        of parameter: Parameter,
        at reference: ParameterReference,
        naming name: UnknownReference
    ) -> PackError {
        .unknownOptionReference(
            place: reference.place,
            kind: reference.kind,
            name: parameter.name,
            option: option,
            reference: name
        )
    }

    // The first name a choice gives that finds no preset of `kind`, read with the arguments written beside it that are
    // plain values, nil where every preset it names is there. `"cut"` and `"none"` name none.
    private func missingPreset(
        in choice: JSONValue,
        kind: PresetKind,
        place: Place
    ) throws -> String? {
        switch choice {
        case .string("cut"), .string("none"):
            return nil

        case let .array(elements):
            for (index, element) in elements.enumerated() {
                if let missing = try missingPreset(in: element, kind: kind, place: place.appending(index: index)) {
                    return missing
                }
            }
            return nil

        // An animation choice names a preset in `preset` and in each side it writes.
        case let .object(object) where kind == .animation:
            for side in ["entrance", "exit"] {
                guard let written = object[side] else { continue }
                if let missing = try missingPreset(in: written, kind: kind, place: place.appending(key: side)) {
                    return missing
                }
            }
            return try missingName(of: choice, kind: kind, place: place)

        default:
            return try missingName(of: choice, kind: kind, place: place)
        }
    }

    // The name a name or an object's `preset` gives where no preset of `kind` has it, nil where it names one that is
    // there or names none.
    private func missingName(
        of choice: JSONValue,
        kind: PresetKind,
        place: Place
    ) throws -> String? {
        guard var instance = PresetInstance(value: choice, place: place) else { return nil }

        instance = PresetInstance(
            name: instance.name,
            arguments: JSONObject(members: instance.arguments.members.filter { $0.value.objectValue?["param"] == nil }),
            place: place
        )
        let isThere = switch kind {
        case .transition:
            try presets.transition(instance) != nil

        case .animation:
            try presets.animation(instance) != nil

        case .filter:
            try presets.filter(instance) != nil

        case .audio:
            try presets.audio(instance) != nil

        case .head:
            try presets.head(named: instance.name) != nil
        }

        return isThere ? nil : instance.name
    }

    // The theme in effect at the end of `components`: the base, under each document's own `theme` on the way there.
    // Nil where a `theme` on the way is still a reference or names no theme, which the instance or the theme's own
    // check stops on.
    private func theme(
        at components: ArraySlice<PlaceComponent>,
        in value: JSONValue,
        place: Place,
        over theme: MergedTheme
    ) throws -> MergedTheme? {
        var theme = theme
        if let object = value.objectValue, object.contains("kind"), let written = object["theme"] {
            guard
                written.objectValue?["param"] == nil,
                let merged = try themes.theme(ThemeReference(value: written), of: place, over: theme)
            else {
                return nil
            }

            theme = merged
        }
        guard let component = components.first else { return theme }

        return try self.theme(
            at: components.dropFirst(),
            in: self.value(at: [component], in: value),
            place: Place(file: place.file, components: place.components + [component]),
            over: theme
        )
    }

    private func value(
        at components: ArraySlice<PlaceComponent>,
        in value: JSONValue
    ) -> JSONValue {
        guard let component = components.first else { return value }

        switch (component, value) {
        case let (.key(key), .object(object)):
            return self.value(at: components.dropFirst(), in: object[key] ?? .null)

        case let (.index(index, _), .array(elements)) where elements.indices.contains(index):
            return self.value(at: components.dropFirst(), in: elements[index])

        default:
            return .null
        }
    }
}
