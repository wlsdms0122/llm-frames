//
//  MediaFactProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What the probe tells about the media a document names, as far as resolve needs it. A file or directory that is not
// there has no facts, and one that is there but cannot be read as media throws why.
package protocol MediaFactProvider: Sendable {
    func probedMedia(of file: String) throws -> ProbedMedia?
    func probedImageSequence(at directory: String) throws -> ProbedImageSequence?
}
