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
    func transition(named name: String) throws -> TransitionPreset? {
        transitions[name]
    }

    func animation(named name: String) throws -> AnimationPreset? {
        animations[name]
    }

    func filter(named name: String) throws -> FilterPreset? {
        filters[name]
    }

    // MARK: - Private
}
