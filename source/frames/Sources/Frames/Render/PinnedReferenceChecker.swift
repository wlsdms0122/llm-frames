//
//  PinnedReferenceChecker.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Checks what a resolved document pins before any role opens it: every pinned file's hash, each file once at the
// first place that pins it, then the decoder on each media once, so a changed file stops before a frame is drawn.
struct PinnedReferenceChecker: Sendable {
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
        for case let .media(media, _) in references {
            let file = MediaFile(media: media)
            guard checked.insert(file.path).inserted else { continue }

            try decoder.check(file)
        }
    }

    // MARK: - Private
    private func checkHash(
        of file: PinnedFile,
        place: String?
    ) throws {
        let digest: String
        do {
            digest = try hasher.sha256(ofFile: file.path)
        } catch {
            throw RenderError.unreadableFile(path: file.path, place: place)
        }

        guard digest == file.sha256 else { throw RenderError.changedFile(path: file.path, place: place) }
    }
}
