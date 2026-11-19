//
//  LeafSource.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Where a timed leaf's value is written and the sequence time it holds: `keyframe` is the index of the keyframe that
// writes it, nil for the merged value at the clip's instant.
struct LeafSource: Equatable, Sendable {
    // MARK: - Property
    let place: LookPlace
    let keyframe: Int?
    let time: Double

    // The place a stop on the value names.
    var written: Place {
        keyframe.map(place.keyframe) ?? place.written
    }

    // MARK: - Initializer
    init(
        place: LookPlace,
        keyframe: Int?,
        time: Double
    ) {
        self.place = place
        self.keyframe = keyframe
        self.time = time
    }

    // MARK: - Public
    // MARK: - Private
}
