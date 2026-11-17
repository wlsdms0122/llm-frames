//
//  PictureSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a picture's pixels come from: a media file or image sequence directory, read through the decoder, or a
// document, which is drawn, not read. `space` has no pixels and no edges: the text box a title gives its children, and
// under content fit the measuring space.
enum PictureSource: Equatable, Sendable {
    case mediaFile(MediaFile)
    case document
    case space
}
