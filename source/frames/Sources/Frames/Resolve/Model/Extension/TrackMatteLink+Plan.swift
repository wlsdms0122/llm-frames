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
    init(plan: StorylinePlan) {
        self.init(
            place: plan.place,
            kind: .clip(plan.source.kind),
            id: plan.id,
            trackMatte: plan.trackMatte,
            refusal: .storyline
        )
    }

    init(plan: ClipPlan) {
        let refusal: TrackMatteRefusal? = switch plan.kind {
        case .adjust:
            .adjustment

        case .media(.audio):
            .audio

        case .media, .title, .shape, .solid:
            nil
        }

        self.init(place: plan.place, kind: .clip(plan.kind), id: plan.id, trackMatte: plan.trackMatte, refusal: refusal)
    }

    // MARK: - Public
    // MARK: - Private
}
