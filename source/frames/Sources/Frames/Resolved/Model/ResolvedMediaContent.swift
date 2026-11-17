//
//  ResolvedMediaContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a storyline entry or media clip shows: pinned media, or the nested resolved sequence of a compound clip, a
// template instance or a document named by its file, in place of a file.
enum ResolvedMediaContent: Equatable, Sendable {
    case pinned(PinnedMedia)
    case nested(ResolvedSequence)
}
