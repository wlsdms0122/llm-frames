//
//  ResolvedSequence+MediaColorSpaces.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// A `colorSpace` is a fact of the medium it is written for, so every place that names a medium (a storyline entry, a
// media clip, a transition's cover or matte, nested sequences included) reads it in one colour space, and its
// tracks have one answer. A file is known by the SHA-256 of what it holds, and a page of a PDF by
// that of its file and its number, and a place that writes no `colorSpace` reads it in the space its tags name, a
// page's untagged colour in `srgb` (FRAMES-26 Media).
extension ResolvedSequence {
    // Media of a file where the document names it: its place, the kind of what names it, and the colour space it is
    // read in there.
    private typealias NamedMedia = (media: PinnedMedia, place: String, kind: String, colorSpace: ColorSpace?)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Two places that read the same medium in different colour spaces stop, naming both. `taggedColorSpaces` holds the
    // space the tags of each file name, by the path of its first pinned file; a file missing there is tagged outside
    // the table, and a place that writes nothing for it is read as its tags say.
    func checkMediaColorSpaces(taggedColorSpaces: [String: ColorSpace]) throws {
        var first: [[String]: [Int?: NamedMedia]] = [:]

        for written in namedMedia(of: self) {
            let files = Self.files(of: written.media)
            let named = (
                media: written.media,
                place: written.place,
                kind: written.kind,
                colorSpace: written.colorSpace ?? files.first.flatMap { taggedColorSpaces[$0.path] }
            )
            let hashes = files.map(\.sha256)
            guard let earlier = first[hashes]?[written.media.page] else {
                first[hashes, default: [:]][written.media.page] = named
                continue
            }
            guard earlier.colorSpace == named.colorSpace else {
                throw ResolveError.mediaColorSpaces(
                    place: named.place,
                    kind: named.kind,
                    other: earlier.place,
                    file: files.first?.path ?? "",
                    colorSpace: named.colorSpace,
                    otherColorSpace: earlier.colorSpace
                )
            }
        }
    }

    // MARK: - Private
    // The media of a file each storyline entry, media clip and transition cover and matte names, in document order,
    // with its place and the colour space it is read in.
    private func namedMedia(of sequence: ResolvedSequence) -> [NamedMedia] {
        let storyline = sequence.storyline.flatMap { entry in
            let media: [NamedMedia] = if case let .media(media) = entry.content {
                namedMedia(of: media.media, place: entry.place, colorSpace: media.colorSpace)
            } else {
                []
            }
            return media + transitionMedia(of: entry.transition, place: "\(entry.place).transition")
        }
        let clips = sequence.clips.flatMap { clip -> [NamedMedia] in
            guard case let .picture(.media(media), _, _) = clip.content else { return [] }

            return namedMedia(of: media.media, place: clip.place, colorSpace: media.colorSpace)
        }

        return storyline + clips
    }

    private func namedMedia(
        of content: ResolvedMediaContent,
        place: String,
        colorSpace: ColorSpace?
    ) -> [NamedMedia] {
        switch content {
        case let .pinned(media):
            [(media, place, "clip", colorSpace)]

        case let .nested(sequence):
            namedMedia(of: sequence)
        }
    }

    private func transitionMedia(
        of transition: ResolvedTransition?,
        place: String
    ) -> [NamedMedia] {
        var named: [NamedMedia] = []
        if case let .media(media)? = transition?.cover?.source {
            named.append((media.media, "\(place).cover", "cover", media.colorSpace))
        }
        if let media = transition?.matte?.media {
            named.append((media.media, "\(place).matte", "matte", media.colorSpace))
        }

        return named
    }

    private static func files(of media: PinnedMedia) -> [PinnedFile] {
        switch media.source {
        case let .file(file, _):
            [file]

        case let .imageSequence(files, _):
            files

        case let .page(file, _):
            [file]
        }
    }
}

