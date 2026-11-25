//
//  ResolvedNull.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A null entry's own keys: how its box is given, and the transform that places it, with its box where `width` and
// `height` give it and without one where its area places it. It draws nothing, so it holds nothing of how a picture is
// drawn and takes no corner pin.
struct ResolvedNull: Equatable, Sendable {
    // MARK: - Property
    let geometry: NullGeometry
    let transform: ResolvedTransform

    // MARK: - Initializer
    init(
        geometry: NullGeometry,
        transform: ResolvedTransform
    ) {
        self.geometry = geometry
        self.transform = transform
    }

    // MARK: - Public
    // MARK: - Private
}
