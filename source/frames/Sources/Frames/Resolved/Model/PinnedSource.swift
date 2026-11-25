//
//  PinnedSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The files a picture or sound is read from: one media file with the media time of each of its frames in frame order,
// nil for an image or a sound file, which has no frames; an image sequence's frame files in frame order with the media
// time of each; or the file of a page of a PDF with its number from 1.
package enum PinnedSource: Equatable, Sendable {
    case file(PinnedFile, frameTimes: [Double]?)
    case imageSequence([PinnedFile], frameTimes: [Double])
    case page(PinnedFile, page: Int)
}
