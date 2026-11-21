//
//  MixMedia.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The media a segment plays: media as a resolved document pins it, or a file nothing pins, as the one medium `loudness`
// measures is played.
package enum MixMedia: Equatable, Sendable {
    case pinned(PinnedMedia)
    case unpinned(path: String)
}
