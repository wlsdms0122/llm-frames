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
        let source: PinnedSource = switch file.kind {
        case let .video(frameTimes, _, _, _):
            .file(try PinnedFile(path: file.path, hashes: hashes), frameTimes: frameTimes.isEmpty ? nil : frameTimes)

        case .still, .sound:
            .file(try PinnedFile(path: file.path, hashes: hashes), frameTimes: nil)

        case let .imageSequence(frameFiles, frameTimes, _, _, _):
            .imageSequence(try frameFiles.map { try PinnedFile(path: $0, hashes: hashes) }, frameTimes: frameTimes)

        case let .page(page, _):
            .page(try PinnedFile(path: file.path, hashes: hashes), page: page)
        }

        self.init(source: source)
    }

    // MARK: - Public
    // MARK: - Private
}
