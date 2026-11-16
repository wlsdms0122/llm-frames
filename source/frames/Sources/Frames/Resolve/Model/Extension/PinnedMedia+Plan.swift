//
//  PinnedMedia+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media file or image sequence as it was probed, pinned: an image sequence is its frame files in order, each pinned,
// so a frame added, removed or changed is refused.
extension PinnedMedia {
    // MARK: - Property
    // MARK: - Initializer
    init(
        file: MediaFile,
        hashes: any FileHashProvider
    ) throws {
        let source: PinnedSource = file.frameFiles.isEmpty
            ? .file(try PinnedFile(path: file.path, hashes: hashes))
            : .imageSequence(try file.frameFiles.map { try PinnedFile(path: $0, hashes: hashes) })

        self.init(source: source, frameTimes: file.frameTimes)
    }

    // MARK: - Public
    // MARK: - Private
}
