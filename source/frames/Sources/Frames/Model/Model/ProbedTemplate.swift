//
//  ProbedTemplate.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A template name with the media kind its probe found.
struct ProbedTemplate: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let kind: MediaKind

    // MARK: - Initializer
    init(
        name: String,
        kind: MediaKind
    ) {
        self.name = name
        self.kind = kind
    }

    // MARK: - Public
    // MARK: - Private
}
