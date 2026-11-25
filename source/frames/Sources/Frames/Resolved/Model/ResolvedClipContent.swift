//
//  ResolvedClipContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a clips entry is: a picture it draws with how that picture composites, or a null, which draws nothing and
// carries a box and a transform for other clips to follow.
enum ResolvedClipContent: Equatable, Sendable {
    case picture(ResolvedPicture, ResolvedComposite)
    case null(ResolvedNull)
}
