//
//  PassedOnThemeTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The themes media in the arguments written at one `args` already keeps when a template passes on what it was given,
// by argument and by place in that argument, so the instance they are given to keeps them too.
struct PassedOnThemeTable: Equatable, Sendable {
    // MARK: - Property
    static let empty = PassedOnThemeTable(themes: [:])

    private let themes: [String: [Place: MergedTheme]]

    // MARK: - Initializer
    init(themes: [String: [Place: MergedTheme]]) {
        self.themes = themes
    }

    // MARK: - Public
    func themes(inArgument name: String) -> [Place: MergedTheme] {
        themes[name] ?? [:]
    }

    // MARK: - Private
}
