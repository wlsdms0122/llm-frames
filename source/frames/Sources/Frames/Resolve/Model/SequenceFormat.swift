//
//  SequenceFormat.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The format keys the time plan reads. Each is nil when the document leaves it to its default.
struct SequenceFormat: Equatable, Sendable {
    // MARK: - Property
    let fps: Double?

    // MARK: - Initializer
    init(fps: Double? = nil) {
        self.fps = fps
    }

    // MARK: - Public
    // MARK: - Private
}
