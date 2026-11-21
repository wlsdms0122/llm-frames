//
//  PinnedSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The files a picture or sound is read from: one media file, an image sequence's frame files in frame order, or the
// file of a page of a PDF with its number from 1.
package enum PinnedSource: Equatable, Sendable {
    case file(PinnedFile)
    case imageSequence([PinnedFile])
    case page(PinnedFile, page: Int)
}
