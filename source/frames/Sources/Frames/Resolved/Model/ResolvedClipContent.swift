//
//  ResolvedClipContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a clips entry is, with how it is placed: a picture it draws, placed by a transform or a corner pin, with how it
// composites; an adjustment's filter, placed by its box alone and over the whole frame where it has none, since it is
// neither scaled nor rotated and takes no corner pin, with how it composites; or a null, which draws nothing and
// carries a box and a transform for other clips to follow (FRAMES-27).
enum ResolvedClipContent: Equatable, Sendable {
    case picture(ResolvedPicture, ResolvedPicturePlacement, ResolvedComposite)
    case adjustment(TimedValue, ResolvedBox?, ResolvedComposite)
    case null(ResolvedNull)
}
