//
//  CrossfadeCurve.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The curve of a transition's sound crossfade, its preset's `audio`: `constant-power` keeps the level of two unrelated
// sounds, and `constant-gain` that of two that are the same signal.
enum CrossfadeCurve: String, CaseIterable, Sendable {
    case constantPower = "constant-power"
    case constantGain = "constant-gain"
}
