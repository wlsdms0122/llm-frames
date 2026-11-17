//
//  ClipSpace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// The coordinate space a clip's positions and areas are written in, at one instant. `transform` is P(t), the map from
// that space to output pixels of the list the clip is drawn in: its parent's chain composed down to the output, or the
// identity for an unparented clip. It is a similarity, so `scale` and `rotation` are its one scale and its turn in
// degrees. `frame` is the list's frame: what a shape without an area covers and what a dim darkens. `storyline` is the
// storyline parent whose media a tracked clip follows.
struct ClipSpace: Sendable {
    // MARK: - Property
    let frame: Rectangle
    let transform: AffineTransform
    let storyline: ResolvedStorylineClip?

    var scale: Double {
        (transform.a * transform.a + transform.b * transform.b).squareRoot()
    }

    var rotation: Double {
        atan2(transform.b, transform.a) * 180 / .pi
    }

    // MARK: - Initializer
    init(
        frame: Rectangle,
        transform: AffineTransform = .identity,
        storyline: ResolvedStorylineClip? = nil
    ) {
        self.frame = frame
        self.transform = transform
        self.storyline = storyline
    }

    // MARK: - Public
    // A clip's area at the time in this space, its keyframes carried by its track when it is tracked.
    func area(
        of keyframes: [Keyframe<Rectangle>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Rectangle {
        guard let track, let storyline else { return keyframes.value(at: time) }

        return track.area(of: keyframes, on: storyline, at: time)
    }

    // Where a box clip's anchor point lands in output pixels at the time: `position + anchor` in this space, carried by
    // its track when it is tracked, then by P(t).
    func anchor(
        of box: ResolvedBox,
        track: ResolvedTrack?,
        at time: Double
    ) -> Point {
        let anchors = box.position.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: Point(x: keyframe.value.x + box.anchor.x, y: keyframe.value.y + box.anchor.y),
                ease: keyframe.ease
            )
        }
        let anchor = track.flatMap { track in storyline.map { track.point(of: anchors, on: $0, at: time) } }
            ?? anchors.value(at: time)

        return transform.apply(to: anchor)
    }

    // MARK: - Private
}
