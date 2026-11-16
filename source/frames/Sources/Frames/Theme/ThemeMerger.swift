//
//  ThemeMerger.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Merges theme layers from weakest to strongest: the base theme, a --theme file, a document's theme, the keys on a clip.
struct ThemeMerger: Sendable {
    // MARK: - Property
    private let validator = ThemeValidator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func merge(
        _ layers: [ThemeLayer],
        over base: MergedTheme = .base
    ) throws -> MergedTheme {
        for layer in layers {
            try validator.checkKeys(of: layer)
        }

        let value = layers.reduce(base.value) { under, over in
            merge(under, over.value, rule: .theme)
        }
        let merged = MergedTheme(value: value, layers: base.layers + layers)
        try validator.checkReferences(in: merged)

        return merged
    }

    // MARK: - Private
    private func merge(
        _ under: JSONValue,
        _ over: JSONValue,
        rule: ThemeMergeRule
    ) -> JSONValue {
        guard case .byKey = rule, case let .object(underObject) = under, case let .object(overObject) = over else {
            return over
        }

        let merged = overObject.members.reduce(underObject) { object, member in
            let value = object[member.key].map { merge($0, member.value, rule: rule.rule(for: member.key)) } ?? member.value
            return object.setting(member.key, to: value)
        }
        return .object(merged)
    }
}
