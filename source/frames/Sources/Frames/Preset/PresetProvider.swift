//
//  PresetProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Finds a preset by the name a document or theme gives it: `<pack>/<name>` or an absolute path.
// A preset that is not there is nil, and one that is there but broken throws.
protocol PresetProvider: Sendable {
    func transition(named name: String) throws -> TransitionPreset?
    func animation(named name: String) throws -> AnimationPreset?
    func filter(named name: String) throws -> FilterPreset?
}
