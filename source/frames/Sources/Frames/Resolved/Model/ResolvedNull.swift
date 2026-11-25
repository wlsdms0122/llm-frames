//
//  ResolvedNull.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A null entry's own keys: how its box is given. It draws nothing, so it holds nothing of how a picture is drawn.
struct ResolvedNull: Equatable, Sendable {
    // MARK: - Property
    let geometry: NullGeometry

    // MARK: - Initializer
    init(geometry: NullGeometry) {
        self.geometry = geometry
    }

    // MARK: - Public
    // MARK: - Private
}
