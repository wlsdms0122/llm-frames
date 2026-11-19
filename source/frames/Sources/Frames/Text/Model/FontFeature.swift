//
//  FontFeature.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An OpenType feature setting, as CSS `font-feature-settings` writes it: 0 turns the feature off, 1 on, and a larger
// value picks an alternate.
package struct FontFeature: Equatable, Hashable, Sendable {
    // MARK: - Property
    package let tag: String
    package let value: Int

    // MARK: - Initializer
    package init(
        tag: String,
        value: Int
    ) {
        self.tag = tag
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
