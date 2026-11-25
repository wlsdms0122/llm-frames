//
//  ResolvedStorylinePlacement.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a storyline entry is placed in the frame: by its box, which `scale` and `rotation` move about its anchor,
// keyframes in sequence time, or by a corner pin, its box's size and the four points in output pixels its corners go
// to (FRAMES-27).
enum ResolvedStorylinePlacement: Equatable, Sendable {
    case transform(box: ResolvedBox, scale: [Keyframe<Scale>], rotation: [Keyframe<Double>])
    case cornerPin(ResolvedCornerPin)

    // MARK: - Property
    // The size of the box its picture fills.
    var size: Size {
        switch self {
        case let .transform(box, _, _):
            box.size

        case let .cornerPin(pin):
            pin.size
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
