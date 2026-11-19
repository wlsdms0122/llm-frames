//
//  TitlePlan.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title as planned: its text set at the static values of its attributes, and its attributes timed, `characters` one
// per run in the title's order and `paragraph` the clip's.
struct TitlePlan: Equatable, Sendable {
    // MARK: - Property
    let layout: TextLayout
    let characters: [TimedValue]
    let paragraph: TimedValue

    // MARK: - Initializer
    init(
        layout: TextLayout,
        characters: [TimedValue],
        paragraph: TimedValue
    ) {
        self.layout = layout
        self.characters = characters
        self.paragraph = paragraph
    }

    // MARK: - Public
    // MARK: - Private
}
