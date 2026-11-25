//
//  ResolvedPicturePlacement.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a title, a shape or a media clip is placed in its parent's space: by a transform, or by a corner pin, which
// places it instead (FRAMES-27). A shape placed by its geometry is placed by a transform without a box. Resolve gives a
// corner pin only to a title, a media clip, and a rect or an ellipse given by `width` and `height`; the resolved reader
// also takes a path with a corner pin, which then draws nothing.
enum ResolvedPicturePlacement: Equatable, Sendable {
    case transform(ResolvedTransform)
    case cornerPin(ResolvedCornerPin)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
