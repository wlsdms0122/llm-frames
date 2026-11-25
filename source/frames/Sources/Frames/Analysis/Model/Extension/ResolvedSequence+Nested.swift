//
//  ResolvedSequence+Nested.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The sequence of the compound clip or template instance at a place, which `timeline --nested` reports (FRAMES-23). A
// nested sequence's places continue the place of the clip that holds it, so a deeper place is looked for inside the
// nested sequence whose place it continues.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func nestedSequence(at place: String) -> ResolvedSequence? {
        let held: [(place: String, media: ResolvedMediaContent?)] = storyline.map { ($0.place, $0.media) }
            + clips.map { clip in
                guard case let .picture(.media(media), _) = clip.content else { return (clip.place, nil) }

                return (clip.place, media.media)
            }
        for (holder, media) in held {
            guard case let .nested(sequence)? = media else { continue }

            if holder == place {
                return sequence
            }
            if place.hasPrefix(holder + ".media."), let nested = sequence.nestedSequence(at: place) {
                return nested
            }
        }

        return nil
    }

    // MARK: - Private
}
