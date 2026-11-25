//
//  ResolvedPicture.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a title, shape or media clip draws: a title's shaped text, a shape, or a media clip.
enum ResolvedPicture: Equatable, Sendable {
    case title(ResolvedText)
    case shape(ResolvedShape)
    case media(ResolvedMediaClip)
}
