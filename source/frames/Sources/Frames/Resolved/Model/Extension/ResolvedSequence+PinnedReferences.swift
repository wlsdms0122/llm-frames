//
//  ResolvedSequence+PinnedReferences.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Everything a resolved sequence pins, nested sequences included, in document order. A file named in several places
// is listed at each.
extension ResolvedSequence {
    // MARK: - Property
    var pinnedReferences: [PinnedReference] {
        references(of: self)
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // A nested sequence's places already continue the place of the clip that holds it.
    private func references(of sequence: ResolvedSequence) -> [PinnedReference] {
        sequence.storyline.flatMap(references(of:))
            + sequence.clips.flatMap(references(of:))
            + sequence.audio.flatMap(references(of:))
    }

    private func references(of entry: ResolvedStorylineClip) -> [PinnedReference] {
        let media = entry.media.map { references(of: $0, place: entry.place, colorSpace: entry.colorSpace) } ?? []
        let transition = entry.transition.map { references(of: $0, place: entry.place) } ?? []

        return media + references(of: entry.filter, place: entry.place) + transition
    }

    private func references(
        of transition: ResolvedTransition,
        place: String
    ) -> [PinnedReference] {
        let cover: [PinnedReference] = if case let .media(media) = transition.cover?.source {
            [.media(media.media, place: place, colorSpace: media.colorSpace)]
        } else {
            []
        }
        let matte = transition.matte.map {
            [PinnedReference.media($0.media.media, place: place, colorSpace: $0.media.colorSpace)]
        } ?? []

        return cover + matte
    }

    private func references(of clip: ResolvedClip) -> [PinnedReference] {
        switch clip.content {
        case let .title(text):
            return references(of: text, place: clip.place)

        case .shape:
            return []

        case let .adjustment(filter):
            return references(of: filter, place: clip.place)

        case let .media(media):
            return references(of: media.media, place: clip.place, colorSpace: media.colorSpace)
                + references(of: media.filter, place: clip.place)
        }
    }

    private func references(of sound: ResolvedSound) -> [PinnedReference] {
        let media = sound.media.map { [PinnedReference.sound($0, place: sound.place)] } ?? []

        return media + sound.nested.flatMap(references(of:))
    }

    private func references(
        of media: ResolvedMediaContent,
        place: String,
        colorSpace: ColorSpace?
    ) -> [PinnedReference] {
        switch media {
        case let .pinned(media):
            [.media(media, place: place, colorSpace: colorSpace)]

        case let .nested(sequence):
            references(of: sequence)
        }
    }

    // A filter's structure is static, so its LUTs are those it holds at any time.
    private func references(
        of filter: TimedValue,
        place: String
    ) -> [PinnedReference] {
        FilterEntry.entries(of: filter, at: 0).flatMap(\.operations).compactMap { operation in
            guard case let .lut(file, _, _) = operation else { return nil }

            return .file(file, place: place)
        }
    }

    private func references(
        of text: ResolvedText,
        place: String
    ) -> [PinnedReference] {
        text.runs.map { run in .file(run.font, place: place) }
    }
}
