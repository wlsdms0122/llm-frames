//
//  UnitPresentation.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a storyline unit's picture is drawn at one instant of a transition: scale and rotation about the centre of the
// content rect, the offset in multiples of the content rect, and `reveal`, the part of the content rect a wipe from
// the span's side has shown, nil when all of it shows. The picture's own coordinates are output pixels, so the reveal
// is in them too.
struct UnitPresentation: Equatable, Sendable {
    // MARK: - Property
    let transform: AffineTransform
    let opacity: Double
    let reveal: Rectangle?

    // MARK: - Initializer
    init(
        sample: MotionSample,
        content: Rectangle
    ) {
        let presentation = ItemPresentation(area: content, opacity: 1, motion: sample.motion)

        self.transform = presentation.transform
        self.opacity = presentation.opacity
        self.reveal = sample.reveal.rectangle(wiping: content, from: sample.revealFrom)
    }

    // MARK: - Public
    // MARK: - Private
}
