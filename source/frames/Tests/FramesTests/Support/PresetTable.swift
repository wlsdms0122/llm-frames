//
//  PresetTable.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

// A fake preset library: the transitions, animations and filters it holds, by name, each filter the JSON a pack
// publishes.
struct PresetTable: PresetProvider {
    // MARK: - Property
    let transitions: [String: TransitionPreset]
    let animations: [String: AnimationPreset]
    let filters: [String: String]

    // MARK: - Initializer
    init(
        transitions: [String: TransitionPreset],
        animations: [String: AnimationPreset],
        filters: [String: String]
    ) {
        self.transitions = transitions
        self.animations = animations
        self.filters = filters
    }

    // MARK: - Public
    // Its transitions and animations are plain and publish no parameters, so any argument stops as an unknown one.
    func transition(_ instance: PresetInstance) throws -> TransitionPreset? {
        try checkArguments(of: instance)
        return transitions[instance.name]
    }

    func animation(_ instance: PresetInstance) throws -> AnimationPreset? {
        try checkArguments(of: instance)
        return animations[instance.name]
    }

    func filter(_ instance: PresetInstance) throws -> FilterPreset? {
        try publishedFilter(named: instance.name).map { try PresetReader().filter($0, instance: instance) }
    }

    func publishedFilter(named name: String) throws -> PublishedPreset<FilterPreset>? {
        guard let text = filters[name] else { return nil }

        return try PresetReader().publishedFilter(from: JSONReader().read(text), place: Place(file: name, components: []))
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
