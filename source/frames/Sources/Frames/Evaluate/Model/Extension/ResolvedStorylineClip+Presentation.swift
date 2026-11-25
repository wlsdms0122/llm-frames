//
//  ResolvedStorylineClip+Presentation.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline entry's own transform and opacity, which carry its box's own pixels into the frame. The transition
// motion is not part of it, since the outer item of its storyline picture carries that. A storyline entry's position
// holds no clip area. An entry with a corner pin has no transform of its own: its corner pin places its box.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func presentation(at time: SampleTime) -> ItemPresentation {
        guard case let .transform(box, scale, rotation) = placement else {
            let size = placement.size
            return ItemPresentation(
                area: Rectangle(x: 0, y: 0, width: size.width, height: size.height),
                opacity: opacity.opacity(at: time),
                motion: Motion()
            )
        }

        let anchor = box.position.mapValues(\.fixed).value(at: time)
        return ItemPresentation(
            box: box.size,
            anchor: box.anchor,
            values: KeyframedValues(
                position: Point(x: anchor.x - box.anchor.x, y: anchor.y - box.anchor.y),
                scale: scale.value(at: time),
                rotation: rotation.value(at: time),
                opacity: opacity.opacity(at: time)
            ),
            motion: Motion()
        )
    }

    // MARK: - Private
}
