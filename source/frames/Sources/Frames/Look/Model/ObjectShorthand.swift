//
//  ObjectShorthand.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A short spelling of an object value, expanded to the leaves it names before it merges: `true` names every key as
// the value below, and a colour names only `key`.
enum ObjectShorthand: Equatable, Sendable {
    case on
    case color(key: String)
}
