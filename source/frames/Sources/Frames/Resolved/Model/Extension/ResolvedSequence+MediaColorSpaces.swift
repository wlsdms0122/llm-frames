//
//  ResolvedSequence+MediaColorSpaces.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// A media clip's `colorSpace` is a fact of its file, so every clip that shows a file, nested sequences included, reads it
// in one colour space and its recognised text and tracks have one answer. A file is known by the SHA-256 of what it
// holds, and a clip that writes no `colorSpace` reads it as its tags say.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Two clips that read the same file in different colour spaces stop, naming both places.
    func checkMediaColorSpaces() throws {
        var first: [[String]: (place: String, colorSpace: ColorSpace?)] = [:]

        for shown in shownMedia(of: self) {
            let files = Self.files(of: shown.media)
            let hashes = files.map(\.sha256)
            guard let earlier = first[hashes] else {
                first[hashes] = (shown.place, shown.colorSpace)
                continue
            }
            guard earlier.colorSpace == shown.colorSpace else {
                throw ResolveError.mediaColorSpaces(
                    place: shown.place,
                    other: earlier.place,
                    file: files.first?.path ?? "",
                    colorSpace: shown.colorSpace,
                    otherColorSpace: earlier.colorSpace
                )
            }
        }
    }

    // MARK: - Private
    // The media of a file each storyline entry and media clip shows, in document order, with its place and the colour
    // space it is read in.
    private func shownMedia(of sequence: ResolvedSequence) -> [(media: PinnedMedia, place: String, colorSpace: ColorSpace?)] {
        let storyline = sequence.storyline.flatMap { entry in
            shownMedia(of: entry.media, place: entry.place, colorSpace: entry.colorSpace)
        }
        let clips = sequence.clips.flatMap { clip -> [(media: PinnedMedia, place: String, colorSpace: ColorSpace?)] in
            guard case let .media(media) = clip.content else { return [] }

            return shownMedia(of: media.media, place: clip.place, colorSpace: media.colorSpace)
        }

        return storyline + clips
    }

    private func shownMedia(
        of content: ResolvedMediaContent?,
        place: String,
        colorSpace: ColorSpace?
    ) -> [(media: PinnedMedia, place: String, colorSpace: ColorSpace?)] {
        switch content {
        case let .pinned(media):
            [(media, place, colorSpace)]

        case let .nested(sequence):
            shownMedia(of: sequence)

        case nil:
            []
        }
    }

    private static func files(of media: PinnedMedia) -> [PinnedFile] {
        switch media.source {
        case let .file(file):
            [file]

        case let .imageSequence(files):
            files
        }
    }
}
