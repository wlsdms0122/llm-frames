//
//  ResolvedMediaContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a storyline entry or media clip shows: pinned media, or a compound clip's, a template instance's or a document's
// nested resolved document in place of a file.
enum ResolvedMediaContent: Equatable, Sendable {
    case pinned(PinnedMedia)
    case nested(ResolvedDocument)
}
