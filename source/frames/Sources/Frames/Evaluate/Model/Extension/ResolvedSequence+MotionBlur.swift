//
//  ResolvedSequence+MotionBlur.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

extension ResolvedSequence {
    // MARK: - Property
    // Whether any clip of the sequence or of a sequence nested in it has `motionBlur`.
    var hasMotionBlur: Bool {
        storyline.contains { entry in
            guard case let .media(media) = entry.content else { return entry.isMotionBlurred }

            return entry.isMotionBlurred || hasMotionBlur(in: media.media)
        }
            || clips.contains { clip in
                guard case let .picture(.media(media), _) = clip.content else { return clip.isMotionBlurred }

                return clip.isMotionBlurred || hasMotionBlur(in: media.media)
            }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func hasMotionBlur(in media: ResolvedMediaContent) -> Bool {
        guard case let .nested(sequence) = media else { return false }

        return sequence.hasMotionBlur
    }
}
