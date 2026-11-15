//
//  AnimationSpan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// An animation span with its length: `seconds` for an entrance or exit, `period` for a loop.
struct AnimationSpan: Equatable, Sendable {
    // MARK: - Property
    let length: Double
    let span: Span

    // MARK: - Initializer
    init(length: Double, span: Span) {
        self.length = length
        self.span = span
    }

    // MARK: - Public
    // MARK: - Private
}
