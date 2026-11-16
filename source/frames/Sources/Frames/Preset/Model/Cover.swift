//
//  Cover.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Only opacity is read from a cover's keys.
struct Cover: Equatable, Sendable {
    // MARK: - Property
    let source: CoverSource
    let span: Span

    // MARK: - Initializer
    init(source: CoverSource, span: Span) {
        self.source = source
        self.span = span
    }

    // MARK: - Public
    // MARK: - Private
}
