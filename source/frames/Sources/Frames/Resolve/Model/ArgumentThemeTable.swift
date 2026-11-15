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
    // media an argument already keeps another theme for, which `passedOnThemes` gives.
    init(
        instance: TemplateInstance,
        place: Place,
        theme: MergedTheme,
        passedOnThemes: PassedOnThemeTable
    ) {
        var themes = [Place: MergedTheme]()
        for argument in instance.arguments {
            let argumentPlace = place.appending(argument.place)
            themes[argumentPlace] = theme
            for (passedOnPlace, passedOnTheme) in passedOnThemes.themes(inArgument: argument.name) {
                themes[argumentPlace.appending(passedOnPlace)] = passedOnTheme
            }
        }

        self.init(themes: themes)
    }

    // MARK: - Public
    func theme(at place: Place) -> MergedTheme? {
        themes[place]
    }

    // The themes kept in the arguments written in the `args` at `place`, at any depth.
    func passedOnThemes(inArgumentsAt place: Place) -> PassedOnThemeTable {
        let depth = place.components.count
        let passedOnThemes = themes.reduce(into: [String: [Place: MergedTheme]]()) { passedOnThemes, entry in
            let components = entry.key.components
            guard
                components.count > depth,
                components.starts(with: place.components),
                case let .key(name) = components[depth]
            else {
                return
            }

            passedOnThemes[name, default: [:]][Place(components: Array(components.dropFirst(depth + 1)))] = entry.value
        }

        return PassedOnThemeTable(themes: passedOnThemes)
    }

    // MARK: - Private
}
