//
//  ResolvedStorylineClip+Space.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline entry's map from the space it gives its children to the frame, before its transition motion, and the
// map of its media pixels, which its mask is in, to the frame. A chain that reaches the output adds the motion after
// them; the entry's own mask, inside its nested list, does not. An entry with a corner pin gives its children output
// pixels, the space its corner pin is written in (FRAMES-10), and its media pixels go onto its box, drawn flat.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func spaceTransform(at time: SampleTime) -> AffineTransform {
        if case .cornerPin = placement { return .identity }

        return pictureTransform(at: time)
    }

    func pictureTransform(at time: SampleTime) -> AffineTransform {
        let own = presentation(at: time).transform
        guard case .media = content else { return own }

        let size = placement.size

        let crop = crop(at: time)
        let bounds = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        return AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
            .concatenating(AffineTransform(mapping: Size(width: crop.width, height: crop.height), onto: bounds))
            .concatenating(own)
    }

    // MARK: - Private
}
