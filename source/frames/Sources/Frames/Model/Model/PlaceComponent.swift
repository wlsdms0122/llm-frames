//
//  PlaceComponent.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum PlaceComponent: Hashable, Sendable {
    case key(String)
    case index(Int, id: String?)

    // MARK: - Property
    var key: String? {
        guard case let .key(key) = self else { return nil }

        return key
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
