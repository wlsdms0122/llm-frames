//
//  ParentPicture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The storyline picture a parented clip is on: the storyline clip's plan, what was found for it, and its picture.
struct ParentPicture: Equatable, Sendable {
    // MARK: - Property
    let plan: StorylinePlan
    let geometry: StorylineGeometry
    let picture: Picture

    // MARK: - Initializer
    init(
        plan: StorylinePlan,
        geometry: StorylineGeometry,
        picture: Picture
    ) {
        self.plan = plan
        self.geometry = geometry
        self.picture = picture
    }

    // MARK: - Public
    // MARK: - Private
}
