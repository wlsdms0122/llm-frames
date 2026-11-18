//
//  ActiveTransition.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Transitions are centred on edit points and no longer than either clip, so at most one holds a time.
struct ActiveTransition: Equatable, Sendable {
    // MARK: - Property
    let incoming: Int
    let transition: ResolvedTransition

    var outgoing: Int {
        incoming - 1
    }

    var range: TimeRange {
        TimeRange(start: transition.start, end: transition.end)
    }

    // MARK: - Initializer
    init?(
        storyline: [ResolvedStorylineClip],
        at time: Double
    ) {
        let incoming = storyline.firstIndex { entry in
            entry.transition.map { TimeRange(start: $0.start, end: $0.end).contains(time) } ?? false
        }
        guard let incoming, let transition = storyline[incoming].transition else { return nil }

        self.incoming = incoming
        self.transition = transition
    }

    // MARK: - Public
    // MARK: - Private
}
