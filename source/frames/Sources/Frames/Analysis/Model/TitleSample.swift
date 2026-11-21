//
//  TitleSample.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A resolved title and the time of the sequence that holds it, which the list without motion blur draws the title at.
struct TitleSample {
    // MARK: - Property
    let text: ResolvedText
    let time: SampleTime

    // MARK: - Initializer
    init(
        text: ResolvedText,
        time: SampleTime
    ) {
        self.text = text
        self.time = time
    }

    // MARK: - Public
    // MARK: - Private
}
