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

    // MARK: - Initializer
    init(
        transitions: [String: TransitionPreset],
        animations: [String: AnimationPreset]
    ) {
        self.transitions = transitions
        self.animations = animations
    }

    // MARK: - Public
    func transition(named name: String) throws -> TransitionPreset? {
        transitions[name]
    }

    func animation(named name: String) throws -> AnimationPreset? {
        animations[name]
    }

    // MARK: - Private
}
