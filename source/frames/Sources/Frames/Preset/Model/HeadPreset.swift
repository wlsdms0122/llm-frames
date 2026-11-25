//
//  HeadPreset.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A head preset as read: its description and the head it draws.
struct HeadPreset: Equatable, Sendable {
    // MARK: - Property
    let description: String
    let head: StrokeHead

    // MARK: - Initializer
    init(
        description: String,
        head: StrokeHead
    ) {
        self.description = description
        self.head = head
    }

    // MARK: - Public
    // MARK: - Private
}
