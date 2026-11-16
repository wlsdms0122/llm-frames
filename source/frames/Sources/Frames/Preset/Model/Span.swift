//
//  Span.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct Span: Equatable, Sendable {
    // MARK: - Property
    let ease: Ease
    let revealFrom: RevealEdge
    let keys: [SpanKey]

    // MARK: - Initializer
    init(
        ease: Ease,
        revealFrom: RevealEdge = .left,
        keys: [SpanKey]
    ) {
        self.ease = ease
        self.revealFrom = revealFrom
        self.keys = keys
    }

    // MARK: - Public
    // MARK: - Private
}
