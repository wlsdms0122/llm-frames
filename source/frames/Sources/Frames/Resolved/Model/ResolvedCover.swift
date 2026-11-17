//
//  ResolvedCover.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A transition's cover: a colour or pinned media over both storyline pictures, and its span, of whose keys only opacity is read.
struct ResolvedCover: Equatable, Sendable {
    // MARK: - Property
    let source: ResolvedCoverSource
    let span: Span

    // MARK: - Initializer
    init(
        source: ResolvedCoverSource,
        span: Span
    ) {
        self.source = source
        self.span = span
    }

    // MARK: - Public
    // MARK: - Private
}
