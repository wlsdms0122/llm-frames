//
//  ResolvedSequence+Title.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// Every title of a sequence and of the sequences nested in it, by place, each with the time the list without motion
// blur samples it at when the sequence is drawn at a time: a nested sequence is sampled at its clip's or storyline
// entry's `mediaTime(at:)`, the time `Evaluator` draws it at in that list. Whether a title is drawn at that time is for
// its items to say.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func titles(at time: Double) -> [String: TitleSample] {
        let nested = storyline.compactMap { entry -> [String: TitleSample]? in
            guard case let .media(media) = entry.content, case let .nested(sequence) = media.media else { return nil }

            return sequence.titles(at: entry.mediaTime(at: time))
        }
        let held = clips.map { clip -> [String: TitleSample] in
            switch clip.content {
            case let .picture(.title(text), _):
                [clip.place: TitleSample(text: text, time: SampleTime(time))]

            case let .picture(.media(media), _):
                if case let .nested(sequence) = media.media {
                    sequence.titles(at: media.mediaTime(at: time))
                } else {
                    [:]
                }

            case .picture(.shape, _), .picture(.adjustment, _), .null:
                [:]
            }
        }

        return (nested + held).reduce(into: [:]) { titles, found in titles.merge(found) { first, _ in first } }
    }

    // MARK: - Private
}
