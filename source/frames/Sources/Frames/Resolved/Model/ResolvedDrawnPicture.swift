//
//  ResolvedDrawnPicture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The picture a drawing step shows: pinned media at a media second, a nested image or layout document, or a compound
// clip's sequence at a time of its own.
enum ResolvedDrawnPicture: Equatable, Sendable {
    case media(PinnedMedia, time: Double)
    case picture(ResolvedPicture)
    case sequence(ResolvedSequence, time: Double)
}
