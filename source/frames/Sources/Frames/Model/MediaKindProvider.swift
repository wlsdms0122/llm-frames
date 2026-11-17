//
//  MediaKindProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The kind of the media a document names, and whether a template is there. Media that is not there is nil, and a
// file or template that is there but cannot be read throws. A media file the probe cannot read throws
// `UnreadableMediaError`.
protocol MediaKindProvider: Sendable {
    func mediaKind(of reference: String) throws -> MediaKind?
    func hasTemplate(named name: String) throws -> Bool
}
