//
//  MediaFile+PinnedMedia.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// The file a decoder reads for pinned media. An image sequence is found at the directory of its frame files, and a page
// is its file with its number. The frame rate and size are not pinned, so a decoder reads them from the file.
extension MediaFile {
    // MARK: - Property
    // MARK: - Initializer
    package init(media: PinnedMedia) {
        switch media.source {
        case let .file(file, frameTimes):
            self.init(path: file.path, frameTimes: frameTimes ?? [])

        case let .imageSequence(files, frameTimes):
            let paths = files.map(\.path)
            let directory = paths.first.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path } ?? ""

            self.init(path: directory, frameTimes: frameTimes, frameFiles: paths)

        case let .page(file, page):
            self.init(path: file.path, page: page)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
