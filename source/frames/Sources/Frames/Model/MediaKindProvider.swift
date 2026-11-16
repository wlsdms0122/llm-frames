//
//  MediaKindProvider.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The kind of the media a document names, and of a template by the kind of document it is. One that is not there is
// nil, and one that is there but cannot be read throws. A media file the probe cannot read gives the probe's failure
// instead of throwing it, so the caller, which knows the place it is named at, stops there.
protocol MediaKindProvider: Sendable {
    func mediaKind(of reference: String) throws -> Result<MediaKind, any Error>?
    func templateKind(of name: String) throws -> MediaKind?
}
