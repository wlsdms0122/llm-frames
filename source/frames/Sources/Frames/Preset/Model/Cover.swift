//
//  Cover.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Only opacity is read from a cover's keys. `colorSpace` is the space a media cover's file is read in, nil where its
// tags apply, and nil for a colour cover.
struct Cover: Equatable, Sendable {
    // MARK: - Property
    let source: CoverSource
    let colorSpace: ColorSpace?
    let span: Span

    // MARK: - Initializer
    init(
        source: CoverSource,
        colorSpace: ColorSpace? = nil,
        span: Span
    ) {
        self.source = source
        self.colorSpace = colorSpace
        self.span = span
    }

    // MARK: - Public
    // MARK: - Private
}
