//
//  TimelineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Where a clip lies at the time `timeline --at` names (FRAMES-23): its box, nil for a clip without one (an audio clip,
// an adjustment clip, a solid), and each of its masks as the quad its geometry's bounding rectangle lands on in output
// pixels, in the order it writes them, nil for a clip that takes no mask (an audio clip, a null, a solid).
struct TimelineGeometry: Equatable, Sendable {
    // MARK: - Property
    static let none = TimelineGeometry(box: nil, masks: nil)

    let box: TimelineBox?
    let masks: [Quad]?

    // MARK: - Initializer
    init(
        box: TimelineBox?,
        masks: [Quad]?
    ) {
        self.box = box
        self.masks = masks
    }

    // MARK: - Public
    // MARK: - Private
}
