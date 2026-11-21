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

    // The page count of `file` where it is a PDF, nil where it is not there or is no PDF. A PDF that opens only with a
    // password throws.
    func pageCount(of file: String) throws -> Int?

    // Page `page` of the PDF `file`, counted from 1, after the checks its decoder makes of a page (FRAMES-3 PDF pages):
    // nil where the file is not there, and a throw where it is no PDF, has no such page, or holds a page the decoder
    // refuses.
    func probedPage(
        _ page: Int,
        of file: String
    ) throws -> ProbedPage?
}
