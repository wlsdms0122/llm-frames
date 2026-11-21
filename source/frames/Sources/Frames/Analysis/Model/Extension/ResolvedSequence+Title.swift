//
//  ResolvedSequence+Title.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Every title of a sequence and of the sequences nested in it, by place, each with the time evaluation samples it at
// when the sequence is drawn at a time: a nested sequence is sampled at its clip's or storyline entry's `mediaTime(at:)`,
// the time `Evaluator` draws it at. Whether a title is drawn at that time is for its items to say.
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
                    sequence.titles(at: media.mediaTime(at: time))
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
