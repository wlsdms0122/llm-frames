//
//  ResolvedSequence+Title.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Every title of a sequence and of the sequences nested in it, by place, each with the time evaluation samples it at
// when the sequence is drawn at a time: a nested sequence is drawn at the media time its clip or storyline entry shows
// then, as `Evaluator` draws it. Whether a title is drawn at that time is for its items to say.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func titles(at time: Double) -> [String: TitleSample] {
        let nested = storyline.compactMap { entry -> [String: TitleSample]? in
            guard case let .nested(sequence) = entry.media else { return nil }

            return sequence.titles(at: entry.mediaTime(at: time))
        }
        let held = clips.map { clip -> [String: TitleSample] in
            switch clip.content {
            case let .title(text):
                [clip.place: TitleSample(text: text, time: time)]

            case let .media(media):
                if case let .nested(sequence) = media.media {
                    sequence.titles(at: media.clock?.mediaTime(atSequenceTime: time) ?? 0)
                } else {
                    [:]
                }

            case .shape, .adjustment:
                [:]
            }
        }

        return (nested + held).reduce(into: [:]) { titles, found in titles.merge(found) { first, _ in first } }
    }

    // MARK: - Private
}
