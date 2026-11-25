//
//  ResolvedPlacement.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a connected clip is placed in its parent's space: by a transform, by a corner pin, or, for an adjustment, by its
// box alone. A title, a shape and a media clip are placed by a transform or a corner pin, a null by a transform, and an
// adjustment, which is neither scaled nor rotated, by its box or over the whole frame where it has none (FRAMES-27).
enum ResolvedPlacement: Equatable, Sendable {
    case transform(ResolvedTransform)
    case cornerPin(ResolvedCornerPin)
    case box(ResolvedBox?)
}
