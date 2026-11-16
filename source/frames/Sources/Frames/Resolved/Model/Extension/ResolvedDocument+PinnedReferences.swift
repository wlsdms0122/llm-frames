//
//  ResolvedDocument+PinnedReferences.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Everything a resolved document pins, nested documents included, in document order. A file named in several places
// is listed at each.
extension ResolvedDocument {
    // MARK: - Property
    var pinnedReferences: [PinnedReference] {
        references(of: self, place: nil)
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // `place` is the clip that holds the document, which the steps of an image or layout have no place of their own
    // under.
    private func references(
        of document: ResolvedDocument,
        place: String?
    ) -> [PinnedReference] {
        switch document {
        case let .sequence(sequence):
            references(of: sequence)

        case let .picture(picture):
            references(of: picture, place: place)
        }
    }

    private func references(of sequence: ResolvedSequence) -> [PinnedReference] {
        sequence.storyline.flatMap(references(of:))
            + sequence.clips.flatMap(references(of:))
            + sequence.audio.flatMap(references(of:))
    }

    private func references(of entry: ResolvedStorylineClip) -> [PinnedReference] {
        let media = entry.media.map { references(of: $0, place: entry.place) } ?? []
        let transition = entry.transition.map { references(of: $0, place: entry.place) } ?? []

        return media + references(of: entry.filter, place: entry.place) + transition
    }

    private func references(
        of transition: ResolvedTransition,
        place: String
    ) -> [PinnedReference] {
        let cover: [PinnedReference] = if case let .media(media) = transition.cover?.source {
            [.media(media.media, place: place)]
        } else {
            []
        }
        let matte = transition.matte.map { [PinnedReference.media($0.media.media, place: place)] } ?? []

        return cover + matte
    }

    private func references(of clip: ResolvedClip) -> [PinnedReference] {
        let label = clip.label.map { references(of: $0.text, place: clip.place) } ?? []

        switch clip.content {
        case let .title(text):
            return references(of: text, place: clip.place) + label

        case .shape:
            return label

        case let .adjustment(filter):
            return references(of: filter, place: clip.place) + label

        case let .media(media):
            return references(of: media.media, place: clip.place)
                + references(of: media.filter, place: clip.place)
                + label
        }
    }

    private func references(of sound: ResolvedSound) -> [PinnedReference] {
        let media = sound.media.map { [PinnedReference.media($0, place: sound.place)] } ?? []

        return media + sound.nested.flatMap(references(of:))
    }

    private func references(
        of picture: ResolvedPicture,
        place: String?
    ) -> [PinnedReference] {
        picture.steps.flatMap { step -> [PinnedReference] in
            switch step.content {
            case let .picture(.media(media, _), _, _):
                [.media(media, place: place)]

            case let .picture(.picture(picture), _, _):
                references(of: picture, place: place)

            case let .picture(.sequence(sequence, _), _, _):
                references(of: sequence)

            case let .adjustment(filter, _):
                references(of: filter, place: place)

            case let .text(text, _):
                references(of: text, place: place)

            case .fill, .box, .dim, .arrow, .border:
                []
            }
        }
    }

    private func references(
        of media: ResolvedMediaContent,
        place: String
    ) -> [PinnedReference] {
        switch media {
        case let .pinned(media):
            [.media(media, place: place)]

        case let .nested(document):
            references(of: document, place: place)
        }
    }

    private func references(
        of filter: [ResolvedFilterOperation],
        place: String?
    ) -> [PinnedReference] {
        filter.compactMap { operation in
            guard case let .lut(file, _) = operation else { return nil }

            return .file(file, place: place)
        }
    }

    private func references(
        of text: ResolvedText,
        place: String?
    ) -> [PinnedReference] {
        text.runs.map { run in .file(run.font, place: place) }
    }
}
