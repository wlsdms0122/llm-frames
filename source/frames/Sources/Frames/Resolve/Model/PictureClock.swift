//
//  PictureClock.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How sequence time becomes the media time of the picture an area is found in: a storyline clip's own media, a media
// clip's own media, or a picture that holds still.
enum PictureClock: Equatable, Sendable {
    case storyline(StorylinePlan)
    case media(MediaTiming)
    case still

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func mediaTime(atSequenceTime time: Double) -> Double {
        switch self {
        case let .storyline(plan):
            plan.mediaTime(atSequenceTime: time)

        case let .media(timing):
            timing.mediaTime(atSequenceTime: time) ?? timing.map.in

        case .still:
            0
        }
    }

    // MARK: - Private
}
