//
//  PictureClock.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How sequence time becomes the media time of the picture an area is found in: a storyline clip's own media, a media
// clip's own media, a picture that holds still, or one frame of the media at every time, the track's frame a `track`
// object's `time` names, where a clip's own geometry under `{"time": t}` is searched (FRAMES-12).
enum PictureClock: Equatable, Sendable {
    case storyline(StorylinePlan)
    case media(MediaClock)
    case still
    case frame(Double)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func mediaTime(atSequenceTime time: Double) -> Double {
        switch self {
        case let .storyline(plan):
            plan.mediaTime(atSequenceTime: time)

        case let .media(clock):
            clock.mediaTime(atSequenceTime: time)

        case .still:
            0

        case let .frame(mediaTime):
            mediaTime
        }
    }

    // MARK: - Private
}
