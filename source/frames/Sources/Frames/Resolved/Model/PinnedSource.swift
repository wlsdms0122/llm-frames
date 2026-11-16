//
//  PinnedSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The files a picture or sound is read from: one media file, or an image sequence's frame files in frame order.
enum PinnedSource: Equatable, Sendable {
    case file(PinnedFile)
    case imageSequence([PinnedFile])
}
