//
//  MediaPictureFinder.swift
//  FramesQuartz
//
//  Created by JSilver on 11/26/26.
//

import Frames

// Finds the media pictures of pixels a display list reads through the renderer's picture cache, each once, as the
// cache keeps it, whichever play reads it: the media frame of every picture item that is no page, every transition matte that is no page and the map of every `displace`
// operation that moves a picture, in each of its sample lists, the lists nested in it and its track mattes' lists. A
// page's pictures are not among them, since the renderer finds their regions and scales as it draws.
struct MediaPictureFinder {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func frames(of list: DisplayList) -> [MediaFrame] {
        var frames: [MediaFrame] = []
        collect(list, into: &frames)

        return frames
    }

    // MARK: - Private
    private func collect(
        _ list: DisplayList,
        into frames: inout [MediaFrame]
    ) {
        switch list.content {
        case let .items(items):
            collect(items, into: &frames)

        case let .samples(samples):
            for sample in samples {
                collect(sample, into: &frames)
            }
        }
    }

    private func collect(
        _ items: [DisplayItem],
        into frames: inout [MediaFrame]
    ) {
        for item in items {
            if let trackMatte = item.trackMatte {
                collect(trackMatte.source, into: &frames)
            }

            switch item.content {
            case let .picture(picture):
                switch picture.source {
                case let .media(frame):
                    add(frame, to: &frames)

                case let .displayList(nested):
                    collect(nested, into: &frames)
                }
                if let matte = picture.matte {
                    add(matte.frame, to: &frames)
                }
                collect(picture.filter, into: &frames)

            case let .adjust(adjust):
                collect(adjust.filter, into: &frames)

            case .path, .glyphs:
                break
            }
        }
    }

    // A displacement map is read as the tagged working values of its file's one frame, as the filter chain reads it.
    private func collect(
        _ filter: [FilterEntry],
        into frames: inout [MediaFrame]
    ) {
        for entry in filter {
            for operation in entry.operations {
                guard case let .displace(file, amount, _) = operation, amount > 0 else { continue }

                add(MediaFrame(media: PinnedMedia(source: .file(file, frameTimes: nil)), index: 0, play: .file), to: &frames)
            }
        }
    }

    private func add(
        _ frame: MediaFrame,
        to frames: inout [MediaFrame]
    ) {
        let isFound = frames.contains {
            $0.media == frame.media && $0.picture == frame.picture && $0.reading == frame.reading
        }
        guard frame.picture != .page, !isFound else { return }

        frames.append(frame)
    }
}
