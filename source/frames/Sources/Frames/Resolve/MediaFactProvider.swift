//
//  MediaFactProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What the probe tells about the media a document names, as far as resolve needs it.
package protocol MediaFactProvider: Sendable {
    func probedMedia(of file: String) -> ProbedMedia?
    func probedImageSequence(at directory: String) -> ProbedImageSequence?
}
