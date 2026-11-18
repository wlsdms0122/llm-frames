//
//  TrackMatteLink+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A planned clip as its track matte chains see it.
extension TrackMatteLink {
    // MARK: - Property
    // MARK: - Initializer
    // A storyline clip is never a track matte.
    init(plan: StorylinePlan) {
        self.init(
            place: plan.place,
            kind: .clip(plan.source.kind),
            id: plan.id,
            trackMatte: plan.trackMatte,
            refusal: "a storyline clip"
        )
    }

    // An adjustment draws no picture of its own and an audio clip none at all, so neither is a track matte.
    init(plan: ClipPlan) {
        let refusal: String? = switch plan.kind {
        case .adjust:
            "an adjustment clip"

        case .media(.audio):
            "an audio clip"

        case .media, .title, .shape, .solid:
            nil
        }

        self.init(place: plan.place, kind: .clip(plan.kind), id: plan.id, trackMatte: plan.trackMatte, refusal: refusal)
    }

    // MARK: - Public
    // MARK: - Private
}
