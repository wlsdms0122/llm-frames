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
        storyline.contains { $0.isMotionBlurred || hasMotionBlur(in: $0.media) }
            || clips.contains { clip in
                guard case let .media(media) = clip.content else { return clip.isMotionBlurred }

                return clip.isMotionBlurred || hasMotionBlur(in: media.media)
            }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func hasMotionBlur(in media: ResolvedMediaContent?) -> Bool {
        guard case let .nested(sequence) = media else { return false }

        return sequence.hasMotionBlur
    }
}
