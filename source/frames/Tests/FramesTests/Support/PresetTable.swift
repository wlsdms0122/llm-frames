//
//  PresetTable.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

// A fake preset library: the transitions and animations it holds, by name.
struct PresetTable: PresetProvider {
    // MARK: - Property
    let transitions: [String: TransitionPreset]
    let animations: [String: AnimationPreset]
    let filters: [String: FilterPreset]

    // MARK: - Initializer
    init(
        transitions: [String: TransitionPreset],
        animations: [String: AnimationPreset],
        filters: [String: FilterPreset]
    ) {
        self.transitions = transitions
        self.animations = animations
        self.filters = filters
    }

    // MARK: - Public
    // The presets it holds are plain and publish no parameters, so any argument stops as an unknown one.
    func transition(_ instance: PresetInstance) throws -> TransitionPreset? {
        try checkArguments(of: instance)
        return transitions[instance.name]
    }

    func animation(_ instance: PresetInstance) throws -> AnimationPreset? {
        try checkArguments(of: instance)
        return animations[instance.name]
    }

    func filter(_ instance: PresetInstance) throws -> FilterPreset? {
        try checkArguments(of: instance)
        return filters[instance.name]
    }

    // MARK: - Private
    private func checkArguments(of instance: PresetInstance) throws {
        _ = try ParameterFiller(checker: KeyChecker()).values(
            of: instance.arguments,
            for: [],
            place: instance.place.appending(key: "args"),
            kind: ChoiceKeyTable.argumentsKind
        )
    }
}
