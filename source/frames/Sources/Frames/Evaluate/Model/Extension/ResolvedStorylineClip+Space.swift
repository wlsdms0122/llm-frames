//
//  ResolvedStorylineClip+Space.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline entry's map from the space it gives its children and its mask to the frame, before its transition
// motion (FRAMES-10): its media pixels through its conformed crop scaled to its box, then its own transform. A solid's
// space is output pixels, carried by its own transform. A chain that reaches the output adds the motion after it, and
// one that ends inside the entry's own nested list, its mask, does not.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func spaceTransform(at time: Double) -> AffineTransform {
        let own = presentation(at: time).transform
        guard media != nil else { return own }

        let crop = crop(at: time)
        let bounds = Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
        return AffineTransform(translation: Point(x: -crop.x, y: -crop.y))
            .concatenating(AffineTransform(mapping: Size(width: crop.width, height: crop.height), onto: bounds))
            .concatenating(own)
    }

    // MARK: - Private
}
