//
//  ThemeDefaults.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The presets a merged theme gives a clip that names none. Anything the theme does not list is `none`.
struct ThemeDefaults: Equatable, Sendable {
    // MARK: - Property
    let transition: TransitionChoice
    let titleAnimations: [String: AnimationChoice]
    let shapeAnimation: AnimationChoice
    let mediaAnimation: AnimationChoice
    let adjustAnimation: AnimationChoice

    // MARK: - Initializer
    init(theme: JSONValue) {
        let defaults = theme.objectValue?["defaults"]?.objectValue
        let animation = defaults?["animation"]?.objectValue
        let titles = animation?["title"]?.objectValue?.members ?? []

        self.transition = defaults?["transition"].flatMap(TransitionChoice.init(value:)) ?? .cut
        self.titleAnimations = Dictionary(
            titles.compactMap { member in AnimationChoice(value: member.value).map { (member.key, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        self.shapeAnimation = animation?["shape"].flatMap(AnimationChoice.init(value:)) ?? .none
        self.mediaAnimation = animation?["media"].flatMap(AnimationChoice.init(value:)) ?? .none
        self.adjustAnimation = animation?["adjust"].flatMap(AnimationChoice.init(value:)) ?? .none
    }

    // MARK: - Public
    func animation(for content: ClipContent) -> AnimationChoice {
        switch content {
        case let .title(style):
            titleAnimations[style] ?? .none

        case .shape:
            shapeAnimation

        case .media:
            mediaAnimation

        case .adjust:
            adjustAnimation
        }
    }

    // MARK: - Private
}
