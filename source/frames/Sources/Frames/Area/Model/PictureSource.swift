//
//  PictureSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Where a picture's pixels come from: a media file or image sequence directory, read through the decoder, or a
// document or a solid, which are drawn, not read. `space` is the text box a title gives its children, which has no
// pixels and no edges.
enum PictureSource: Equatable, Sendable {
    case mediaFile(MediaFile)
    case document
    case solid
    case space
}
