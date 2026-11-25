//
//  MediaKind+PinnedMedia.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The kind of pinned picture media: a file with frame times or an image sequence is a video, a file without them an
// image, and a page a page.
extension MediaKind {
    // MARK: - Property
    // MARK: - Initializer
    init(pinned media: PinnedMedia) {
        switch media.source {
        case .file(_, .some), .imageSequence:
            self = .video

        case .file(_, nil):
            self = .image

        case .page:
            self = .page
        }
    }

    // MARK: - Public
    // MARK: - Private
}
