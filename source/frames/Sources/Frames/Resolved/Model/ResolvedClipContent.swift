//
//  ResolvedClipContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a clips entry draws: a title's shaped text, a shape, an adjustment's filter, or a media clip.
enum ResolvedClipContent: Equatable, Sendable {
    case title(ResolvedText)
    case shape(ResolvedShape)
    case adjustment(TimedValue)
    case media(ResolvedMediaClip)
}
