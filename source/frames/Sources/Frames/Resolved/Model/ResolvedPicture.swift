//
//  ResolvedPicture.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a clips entry with a picture draws: a title's shaped text, a shape, an adjustment's filter, or a media clip.
enum ResolvedPicture: Equatable, Sendable {
    case title(ResolvedText)
    case shape(ResolvedShape)
    case adjustment(TimedValue)
    case media(ResolvedMediaClip)
}
