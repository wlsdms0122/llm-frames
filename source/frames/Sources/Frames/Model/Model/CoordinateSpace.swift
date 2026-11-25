//
//  CoordinateSpace.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The space a clip's coordinates are written in (FRAMES-10): output pixels of the frame, the media pixels of the clip at
// a place, a compound clip's being its nested sequence's output pixels, the box of the clip at a place, a title's text
// box with its background or a rect's or ellipse's placed by `width` and `height`, or the text box of the title at a
// place, which its masks lie in. A place is written as reports write it.
enum CoordinateSpace: Equatable, Sendable {
    case output
    case media(String)
    case box(String)
    case text(String)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
