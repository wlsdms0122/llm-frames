//
//  MediaKindProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The kind of the media a document names, the page count of a PDF it names, and whether a template is there. Media
// that is not there is nil, and so is the page count of media that is not a PDF. A file or template that is there but
// cannot be read throws. A media file the probe cannot read throws `UnreadableMediaError`.
protocol MediaKindProvider: Sendable {
    func mediaKind(of reference: String) throws -> MediaKind?
    func pageCount(of reference: String) throws -> Int?
    func hasTemplate(named name: String) throws -> Bool
}
