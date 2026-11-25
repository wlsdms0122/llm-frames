//
//  ResolvedPicturePlacement.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a title, a shape or a media clip is placed in its parent's space: by a transform, or by a corner pin, which
// places it instead (FRAMES-27). A shape placed by its geometry is placed by a transform without a box. A corner pin
// places only a title, a media clip, and a rect or an ellipse given by `width` and `height`.
enum ResolvedPicturePlacement: Equatable, Sendable {
    case transform(ResolvedTransform)
    case cornerPin(ResolvedCornerPin)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
