//
//  PresetKind.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The kinds of preset, each a folder of a pack's `presets/`.
package enum PresetKind: String, CaseIterable, Sendable {
    case transition
    case animation
    case filter
    case audio
}
