//
//  ArgumentThemeTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Media a template instance was given keeps the theme of the document that wrote it, so this holds that theme by the
// place the media stands at in the instance being read.
struct ArgumentThemeTable: Equatable, Sendable {
    // MARK: - Property
    static let empty = ArgumentThemeTable(themes: [:])

    private let themes: [Place: MergedTheme]

    // MARK: - Initializer
    init(themes: [Place: MergedTheme]) {
        self.themes = themes
    }

    // An instance at `place` is written where `theme` is in effect, so what it was given keeps that theme, except
    // media an argument already keeps another theme for, which `kept` gives by argument and by place in it.
    init(
        instance: TemplateInstance,
        place: Place,
        theme: MergedTheme,
        kept: [String: [Place: MergedTheme]]
    ) {
        var themes = [Place: MergedTheme]()
        for argument in instance.arguments {
            let argumentPlace = place.appending(argument.place)
            themes[argumentPlace] = theme
            for (keptPlace, keptTheme) in kept[argument.name] ?? [:] {
                themes[argumentPlace.appending(keptPlace)] = keptTheme
            }
        }

        self.init(themes: themes)
    }

    // MARK: - Public
    func theme(at place: Place) -> MergedTheme? {
        themes[place]
    }

    // The themes kept in each argument written in the `args` at `place`, by argument and by place in it, at any depth,
    // so the instance they are given to keeps them too.
    func kept(inArgumentsAt place: Place) -> [String: [Place: MergedTheme]] {
        let depth = place.components.count

        return themes.reduce(into: [String: [Place: MergedTheme]]()) { kept, entry in
            let components = entry.key.components
            guard
                components.count > depth,
                components.starts(with: place.components),
                case let .key(name) = components[depth]
            else {
                return
            }

            kept[name, default: [:]][Place(components: Array(components.dropFirst(depth + 1)))] = entry.value
        }
    }

    // MARK: - Private
}
