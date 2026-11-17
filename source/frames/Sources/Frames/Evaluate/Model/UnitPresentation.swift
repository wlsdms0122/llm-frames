//
//  UnitPresentation.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a storyline unit's picture is drawn at one instant of a transition: scale and rotation about the centre of the
// frame, the offset in multiples of the frame, and `reveal`, the part of the frame a wipe from the span's side has
// shown, nil when all of it shows. The picture's own coordinates are output pixels, so the reveal is in them too.
struct UnitPresentation: Equatable, Sendable {
    // MARK: - Property
    let transform: AffineTransform
    let opacity: Double
    let reveal: Rectangle?

    // MARK: - Initializer
    init(
        sample: MotionSample,
        frame: Rectangle
    ) {
        let presentation = ItemPresentation(area: frame, opacity: 1, motion: sample.motion)

        self.transform = presentation.transform
        self.opacity = presentation.opacity
        self.reveal = sample.reveal.rectangle(wiping: frame, from: sample.revealFrom)
    }

    // MARK: - Public
    // MARK: - Private
}
