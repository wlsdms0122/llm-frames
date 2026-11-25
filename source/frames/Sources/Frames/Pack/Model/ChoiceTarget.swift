//
//  ChoiceTarget.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a template's choice names where it stands, which resolve looks up there. A preset is the whole preset choice
// at `choice`, of which the reference stands for `part`.
enum ChoiceTarget: Equatable, Sendable {
    case preset(PresetKind, choice: [PlaceComponent], part: ChoicePart)
    case theme
    case textStyle
    case shapeStyle
    case color

    // MARK: - Property
    var label: String {
        switch self {
        case let .preset(kind, _, _):
            "\(kind.rawValue) preset"

        case .theme:
            "theme"

        case .textStyle:
            "text style"

        case .shapeStyle:
            "shape style"

        case .color:
            "theme colour"
        }
    }

    // MARK: - Initializer
    // A reference inside a theme object is the theme's to check, so only the theme a document names is a target there.
    init?(reference: ParameterReference) {
        let components = reference.place.components
        let lastKey = components.last.flatMap(\.key)
        if lastKey == "theme", reference.type == DocumentKeyTable.theme {
            self = .theme
            return
        }
        guard !components.contains(.key("theme")) else { return nil }

        if let preset = Self.preset(of: reference) {
            self = preset
            return
        }

        switch (lastKey, reference.type) {
        case ("style", _) where [ClipKind.title.label, ClipKeyTable.run.kind].contains(reference.kind):
            self = .textStyle

        case ("style", _) where VocabularyTable.shapes.contains(reference.kind):
            self = .shapeStyle

        case (_, .color):
            self = .color

        case let (_, .oneOf(types)) where types.contains(.color):
            self = .color

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
    // The choice is under the clip key that takes it, and a side of an animation or an item of a filter or audio filter
    // list is a whole choice of its own.
    private static func preset(of reference: ParameterReference) -> ChoiceTarget? {
        let components = reference.place.components
        guard
            let index = components.lastIndex(where: { $0.key.flatMap(ClipKeyTable.choice(ofKey:)) != nil }),
            let type = components[index].key.flatMap(ClipKeyTable.choice(ofKey:)),
            let kind = ChoiceKeyTable.presetKind(of: type)
        else {
            return nil
        }

        var choice = Array(components[...index])
        var rest = components[(index + 1)...]
        switch (kind, rest.first) {
        case (.animation, .key("entrance")?), (.animation, .key("exit")?), (.filter, .index?), (.audio, .index?):
            choice.append(rest.removeFirst())

        default:
            break
        }

        let part: ChoicePart
        switch Array(rest) {
        case []:
            guard ChoiceKeyTable.presetKind(of: reference.type) == kind else { return nil }

            part = .whole

        case [.key("preset")]:
            guard
                reference.kind.hasSuffix("choice") || reference.kind == ChoiceKeyTable.animationSideKind
            else {
                return nil
            }

            part = .name

        case let written where written.count == 2 && written.first == .key("args"):
            guard reference.kind == ChoiceKeyTable.argumentsKind else { return nil }

            part = .argument

        default:
            return nil
        }

        return .preset(kind, choice: choice, part: part)
    }
}
