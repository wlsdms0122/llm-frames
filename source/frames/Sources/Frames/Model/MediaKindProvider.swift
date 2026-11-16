//
//  MediaKindProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The kind of the media a document names, and of a template by the kind of document it is. One that is not there is
// nil, and one that is there but cannot be read throws. A media file the probe cannot read throws
// `UnreadableMediaError`.
protocol MediaKindProvider: Sendable {
    func mediaKind(of reference: String) throws -> MediaKind?
    func templateKind(of name: String) throws -> MediaKind?
}
