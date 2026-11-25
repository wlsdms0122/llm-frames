//
//  PinnedMedia+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media file, image sequence or page of a PDF as it was probed, pinned: an image sequence is its frame files in
// order, each pinned, so a frame added, removed or changed is refused, and a page is its file with its number.
extension PinnedMedia {
    // MARK: - Property
    // MARK: - Initializer
    init(
        file: MediaFile,
        hashes: any FileHashProvider
    ) throws {
        let source: PinnedSource = if let page = file.page {
            .page(try PinnedFile(path: file.path, hashes: hashes), page: page)
        } else if file.frameFiles.isEmpty {
            .file(
                try PinnedFile(path: file.path, hashes: hashes),
                frameTimes: file.frameTimes.isEmpty ? nil : file.frameTimes
            )
        } else {
            .imageSequence(
                try file.frameFiles.map { try PinnedFile(path: $0, hashes: hashes) },
                frameTimes: file.frameTimes
            )
        }

        self.init(source: source)
    }

    // MARK: - Public
    // MARK: - Private
}
