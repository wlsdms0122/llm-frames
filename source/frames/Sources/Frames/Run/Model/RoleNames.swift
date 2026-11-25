//
//  RoleNames.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The name of the implementation that filled each role of a run (FRAMES-21).
package struct RoleNames: Equatable, Sendable {
    // MARK: - Property
    package let decoder: String
    package let renderer: String
    package let mixer: String
    package let encoder: String

    // MARK: - Initializer
    package init(
        decoder: String,
        renderer: String,
        mixer: String,
        encoder: String
    ) {
        self.decoder = decoder
        self.renderer = renderer
        self.mixer = mixer
        self.encoder = encoder
    }

    // MARK: - Public
    // MARK: - Private
}
