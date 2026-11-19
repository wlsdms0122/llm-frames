//
//  ResolvedSequence+MediaColorSpaces.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// A `colorSpace` is a fact of the file it is written for, so every place that names a file (a storyline entry, a media
// clip, a transition's cover or matte, nested sequences included) reads it in one colour space, and its recognised
// text and tracks have one answer. A file is known by the SHA-256 of what it holds, and a place that writes no
// `colorSpace` reads it as its tags say.
extension ResolvedSequence {
    // Media of a file where the document names it: its place, the kind of what names it, and the colour space it is
    // read in there.
    private typealias NamedMedia = (media: PinnedMedia, place: String, kind: String, colorSpace: ColorSpace?)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Two places that read the same file in different colour spaces stop, naming both.
    func checkMediaColorSpaces() throws {
        var first: [[String]: NamedMedia] = [:]

        for named in namedMedia(of: self) {
            let files = Self.files(of: named.media)
            let hashes = files.map(\.sha256)
            guard let earlier = first[hashes] else {
                first[hashes] = named
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
            namedMedia(of: entry.media, place: entry.place, colorSpace: entry.colorSpace)
                + transitionMedia(of: entry.transition, place: "\(entry.place).transition")
        }
        let clips = sequence.clips.flatMap { clip -> [NamedMedia] in
            guard case let .media(media) = clip.content else { return [] }

            return namedMedia(of: media.media, place: clip.place, colorSpace: media.colorSpace)
        }

        return storyline + clips
    }

    private func namedMedia(
        of content: ResolvedMediaContent?,
        place: String,
        colorSpace: ColorSpace?
    ) -> [NamedMedia] {
        switch content {
        case let .pinned(media):
            [(media, place, "clip", colorSpace)]

        case let .nested(sequence):
            namedMedia(of: sequence)

        case nil:
            []
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
        case let .file(file):
            [file]

        case let .imageSequence(files):
            files
        }
    }
}

