//
//  ResolvedSolid.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// A solid storyline entry's content: `color`, keyframes in sequence time, filling a frame of `size`, its sequence's,
// whose `conform` is how storyline crops fill that frame. A solid takes none of the keys that place or draw a picture,
// so its picture is the frame's: its box the frame, placed at the frame's centre by the identity transform, its crop
// the whole frame conformed to it, at opacity 1 with `blend` `normal`, and no mask, track matte, track, filter,
// radius, border or shadow.
struct ResolvedSolid: Equatable, Sendable {
    // MARK: - Property
    let color: [Keyframe<Color>]
    let size: Size
    let conform: Conform

    // MARK: - Initializer
    init(
        color: [Keyframe<Color>],
        size: Size,
        conform: Conform
    ) {
        self.color = color
        self.size = size
        self.conform = conform
    }

    // MARK: - Public
    // Its picture with every static value a keyframe at `instant`, the entry's start.
    func picture(at instant: Double) -> ResolvedStorylinePicture {
        let frame = Rectangle(x: 0, y: 0, width: size.width, height: size.height)

        return ResolvedStorylinePicture(
            placement: .transform(
                box: ResolvedBox(
                    size: size,
                    position: .keyframes([Keyframe(at: instant, value: .point(frame.center))]),
                    anchor: frame.center
                ),
                scale: [Keyframe(at: instant, value: .identity)],
                rotation: [Keyframe(at: instant, value: 0)]
            ),
            crop: .keyframes([Keyframe(at: instant, value: Crop(CropConformer().conformed(frame, to: frame, by: conform)))]),
            mask: nil,
            trackMatte: nil,
            track: nil,
            filter: .off,
            opacity: [Keyframe(at: instant, value: 1)],
            blend: "normal",
            radius: .off,
            border: .off,
            shadow: .off
        )
    }

    // MARK: - Private
}
