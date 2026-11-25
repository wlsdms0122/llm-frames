//
//  SequencePlan+Nested.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The plan of the sequence nested at a place, which `timeline --nested` reports (FRAMES-23), as it is planned there. A
// nested plan's places continue the place of the clip that holds it, so a deeper place is looked for inside the nested
// plan whose place it continues.
extension SequencePlan {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func nestedPlan(at place: String) -> SequencePlan? {
        let held = time.storyline.indices.map { (time.storyline[$0].place.description, storyline[$0].nested) }
            + time.clips.indices.map { (time.clips[$0].place.description, clips[$0].nested) }
        for (holder, nested) in held {
            guard let nested else { continue }

            if holder == place {
                return nested
            }
            if place.hasPrefix(holder + ".media."), let deeper = nested.nestedPlan(at: place) {
                return deeper
            }
        }

        return nil
    }

    // MARK: - Private
}
