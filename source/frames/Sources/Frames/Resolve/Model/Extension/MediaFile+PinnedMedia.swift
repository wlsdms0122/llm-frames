//
//  MediaFile+PinnedMedia.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// The file a decoder reads for pinned media. An image sequence is found at the directory of its frame files, and a page
// is its file with its number. Pinned media names one kind of file without frames for an image and a sound file, so
// the place that reads it says which: a picture's media is an image, and a sound's a sound file. The frame rate, size
// and colour reading are not pinned, so a decoder reads them from the file.
extension MediaFile {
    // MARK: - Property
    // MARK: - Initializer
    // The file of pinned media a picture is read from.
    package init(picture media: PinnedMedia) {
        self.init(media: media, withoutFrames: .still(size: nil, colorReading: nil))
    }

    // The file of pinned media a sound is read from.
    package init(sound media: PinnedMedia) {
        self.init(media: media, withoutFrames: .sound)
    }

    // MARK: - Public
    // MARK: - Private
    private init(
        media: PinnedMedia,
        withoutFrames: MediaFileKind
    ) {
        switch media.source {
        case let .file(file, frameTimes):
            let kind: MediaFileKind = if let frameTimes {
                .video(frameTimes: frameTimes, fps: nil, size: nil, colorReading: nil)
            } else {
                withoutFrames
            }
            self.init(path: file.path, kind: kind)

        case let .imageSequence(files, frameTimes):
            let paths = files.map(\.path)
            let directory = paths.first.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path } ?? ""

            self.init(
                path: directory,
                kind: .imageSequence(frameFiles: paths, frameTimes: frameTimes, fps: nil, size: nil, colorReading: nil)
            )

        case let .page(file, page):
            self.init(path: file.path, kind: .page(page, size: nil))
        }
    }
}
