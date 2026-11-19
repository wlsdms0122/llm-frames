//
//  ClipTitle.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title as written: its runs, the clip's style, and its `character` and `paragraph`, merged over its runs' styles
// and over its style's paragraph attributes.
struct ClipTitle: Equatable, Sendable {
    // MARK: - Property
    let runs: [TitleRun]
    let style: String
    let character: LookProperty?
    let paragraph: LookProperty?

    // MARK: - Initializer
    init(
        runs: [TitleRun],
        style: String,
        character: LookProperty?,
        paragraph: LookProperty?
    ) {
        self.runs = runs
        self.style = style
        self.character = character
        self.paragraph = paragraph
    }

    // MARK: - Public
    // MARK: - Private
}
