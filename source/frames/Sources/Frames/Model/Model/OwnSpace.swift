//
//  OwnSpace.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A connected or sequence clip's own coordinate space, which its mask is written in and which it gives its children: a
// media clip's media pixels, the box of a title or of a rect or ellipse given by `width` and `height`, and for a shape
// placed by its geometry or an adjustment the space its parent gives, output pixels without one. A storyline clip's is
// always its media.
enum OwnSpace: Equatable, Sendable {
    case media
    case box
    case parent

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
