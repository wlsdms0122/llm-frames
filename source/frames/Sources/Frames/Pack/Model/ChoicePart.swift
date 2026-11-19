//
//  ChoicePart.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// What part of a preset choice a template's reference stands for: the whole choice, its `preset`, or one of its
// `args`.
enum ChoicePart: Equatable, Sendable {
    case whole
    case name
    case argument
}
