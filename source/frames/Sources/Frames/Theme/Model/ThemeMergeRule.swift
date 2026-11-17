//
//  ThemeMergeRule.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// How far merging goes key by key. Below the last `byKey`, a value replaces the one under it whole.
indirect enum ThemeMergeRule: Sendable {
    case replace
    case byKey([String: ThemeMergeRule], others: ThemeMergeRule)

    // MARK: - Property
    static let theme = ThemeMergeRule.byKey(
        [
            "colors": .byKey([:], others: .replace),
            "styles": .byKey([:], others: .byKey([:], others: .replace)),
            "shapes": .byKey([:], others: .byKey([:], others: .replace)),
            "area": .byKey([:], others: .replace),
            "placement": .byKey([:], others: .replace),
            "border": .byKey([:], others: .replace),
            "shadow": .byKey([:], others: .replace),
            "defaults": .byKey(
                [
                    "animation": .byKey(
                        ["title": .byKey([:], others: .replace)],
                        others: .replace
                    )
                ],
                others: .replace
            )
        ],
        others: .replace
    )

    // MARK: - Initializer
    // MARK: - Public
    func rule(for key: String) -> ThemeMergeRule {
        guard case let .byKey(children, others) = self else { return .replace }

        return children[key] ?? others
    }

    // MARK: - Private
}
