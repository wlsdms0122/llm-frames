//
//  ResolvedSequence+PinnedReferences.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Everything a resolved sequence pins, nested sequences included, in document order, its own audio filter's last. A
// file named in several places is listed at each.
extension ResolvedSequence {
    // MARK: - Property
    var pinnedReferences: [PinnedReference] {
        references(of: self) + references(ofAudioFilter: audioFilter, place: AudioFilterResolver.key)
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
        case let .picture(.title(text), _):
            return references(of: text, place: clip.place)

        case .picture(.shape, _), .null:
            return []

        case let .picture(.adjustment(filter), _):
            return references(of: filter, place: clip.place)

        case let .picture(.media(media), _):
            return references(of: media.media, place: clip.place, colorSpace: media.colorSpace)
                + references(of: media.filter, place: clip.place)
        }
    }

    // A nested sequence's own audio filter is its sound's `nestedAudioFilter`.
    private func references(of sound: ResolvedSound) -> [PinnedReference] {
        let media = sound.media.map { [PinnedReference.sound($0, place: sound.place)] } ?? []

        return media
            + sound.nested.flatMap(references(of:))
            + references(ofAudioFilter: sound.nestedAudioFilter, place: sound.place)
            + references(ofAudioFilter: sound.audioFilter, place: sound.place)
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

    // A filter's structure is static, so its LUTs and displacement maps are those it holds at any time. A map's picture
    // is read as its tags say.
    private func references(
        of filter: TimedValue,
        place: String
    ) -> [PinnedReference] {
        FilterEntry.entries(of: filter, at: SampleTime(0)).flatMap(\.operations).compactMap { operation in
            switch operation {
            case let .lut(file, _, _):
                .file(file, place: place)

            case let .displace(file, _, _):
                .media(PinnedMedia(source: .file(file)), place: place, colorSpace: nil)

            case .exposure, .contrast, .saturation, .temperature, .hue, .sepia, .levels, .blur, .sharpen, .bloom,
                .vignette, .pixelate, .grain:
                nil
            }
        }
    }

    // An audio filter's structure is static, so its impulse responses are those it holds at any time. Only the sound
    // of an impulse response is read.
    private func references(
        ofAudioFilter filter: TimedValue,
        place: String
    ) -> [PinnedReference] {
        guard case let .list(entries) = filter else { return [] }

        return entries.flatMap { entry -> [PinnedReference] in
            guard case let .list(operations)? = entry["ops"] else { return [] }

            return operations.compactMap { operation in
                guard
                    case let .form(name, body) = operation,
                    name == "op:convolve",
                    case let .fixed(.string(path))? = body["file"],
                    case let .fixed(.string(sha256))? = body["sha256"]
                else {
                    return nil
                }

                return .sound(PinnedMedia(source: .file(PinnedFile(path: path, sha256: sha256))), place: place)
            }
        }
    }

    private func references(
        of text: ResolvedText,
        place: String
    ) -> [PinnedReference] {
        text.runs.map { run in .file(run.font, place: place) }
    }
}
