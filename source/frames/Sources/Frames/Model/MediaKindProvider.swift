//
//  MediaKindProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What the media a document names is, a PDF by its page count, and whether a template is there. Media that is not
// there is nil. A file or template that is there but cannot be read throws. A media file the probe cannot read throws
// `UnreadableMediaError`.
protocol MediaKindProvider: Sendable {
    func mediaKind(of reference: String) throws -> ProbedKind?
    func hasTemplate(named name: String) throws -> Bool
}
