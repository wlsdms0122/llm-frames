//
//  PinnedReferenceChecker.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Checks what a resolved document pins before any role opens it: every pinned file's hash, each file once at the
// first place that pins it, then the decoder on each media once, and again for each other colour space its pictures
// are read in, so a changed file, or a picture no fixed formula converts read with no colour space written, stops
// before the role reads anything.
struct PinnedReferenceChecker: Sendable {
    // A media file or a page of one whose pictures the decoder checked, and the colour space they are read in.
    private struct CheckedPictures: Hashable {
        let path: String
        let page: Int?
        let colorSpace: ColorSpace?
    }

    // MARK: - Property
    private let decoder: any MediaDecoder
    private let hasher: any FileHashProvider

    // MARK: - Initializer
    init(
        decoder: any MediaDecoder,
        hasher: any FileHashProvider
    ) {
        self.decoder = decoder
        self.hasher = hasher
    }

    // MARK: - Public
    func check(_ references: [PinnedReference]) throws {
        var hashed: Set<String> = []
        for reference in references {
            for file in reference.files where hashed.insert(file.path).inserted {
                try checkHash(of: file, place: reference.place)
            }
        }

        var checked: Set<String> = []
        var checkedPictures: Set<CheckedPictures> = []
        for reference in references {
            switch reference {
            case let .media(media, _, colorSpace):
                let file = MediaFile(media: media)
                guard checkedPictures.insert(CheckedPictures(path: file.path, page: file.page, colorSpace: colorSpace)).inserted else {
                    continue
                }
                checked.insert(file.path)

                // The check of a picture's colour depends only on the colour space it is read in.
                try decoder.check(file, reading: .working(colorSpace: colorSpace, targetPeak: nil))

            case let .sound(media, _):
                let file = MediaFile(media: media)
                guard checked.insert(file.path).inserted else { continue }

                try decoder.check(file, reading: nil)

            case .file:
                continue
            }
        }
    }

    // MARK: - Private
    private func checkHash(
        of file: PinnedFile,
        place: String
    ) throws {
        let digest: String
        do {
            digest = try hasher.sha256(ofFile: file.path)
        } catch {
            throw PinnedReferenceError.unreadableFile(path: file.path, place: place)
        }

        guard digest == file.sha256 else { throw PinnedReferenceError.changedFile(path: file.path, place: place) }
    }
}
