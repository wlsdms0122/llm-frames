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
        let isThere: Bool
        switch target {
        case let .preset(kind, choice, part):
            let place = Place(file: reference.place.file, components: choice)
            let found = try presetsAreThere(value(at: choice[...], in: document), kind: kind, place: place)
            // An argument is not what names the preset, so a preset that is not there is resolve's to stop on.
            guard found || part != .argument else { return }

            isThere = found

        case .theme:
            isThere = try option.stringValue.map { try library.theme(named: $0) != nil } ?? true

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

            isThere = switch target {
            case .textStyle:
                theme.styleNames.contains(name)

            case .shapeStyle:
                theme.shapeStyle(named: name) != nil

            default:
                theme.isColor(name)
            }
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

    // Each preset a choice names, with the arguments written beside it that are plain values. `"cut"` and `"none"`
    // name none.
    private func presetsAreThere(
        _ choice: JSONValue,
        kind: PresetKind,
        place: Place
    ) throws -> Bool {
        switch choice {
        case .string("cut"), .string("none"):
            return true

        case let .array(elements):
            for (index, element) in elements.enumerated() {
                guard try presetsAreThere(element, kind: kind, place: place.appending(index: index)) else { return false }
            }
            return true

        case let .object(object) where object.contains("entrance"):
            for side in ["entrance", "exit"] {
                guard
                    try presetsAreThere(object[side] ?? .null, kind: kind, place: place.appending(key: side))
                else {
                    return false
                }
            }
            return true

        default:
            guard var instance = PresetInstance(value: choice, place: place) else { return true }

            instance = PresetInstance(
                name: instance.name,
                arguments: JSONObject(members: instance.arguments.members.filter { $0.value.objectValue?["param"] == nil }),
                place: place
            )
            switch kind {
            case .transition:
                return try presets.transition(instance) != nil

            case .animation:
                return try presets.animation(instance) != nil

            case .filter:
                return try presets.filter(instance) != nil

            case .audio:
                return try presets.audio(instance) != nil

            case .head:
                return try presets.head(named: instance.name) != nil
            }
        }
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
