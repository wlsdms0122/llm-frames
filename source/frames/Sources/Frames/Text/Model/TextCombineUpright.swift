//
//  TextCombineUpright.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// Whether a run's text on each of its vertical lines is set as one horizontal-in-vertical composition, side by side in
// one upright square 1 em long, as CSS `text-combine-upright` names it. A horizontal line combines none.
enum TextCombineUpright: String, CaseIterable, Equatable, Sendable {
    case none
    case all

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
