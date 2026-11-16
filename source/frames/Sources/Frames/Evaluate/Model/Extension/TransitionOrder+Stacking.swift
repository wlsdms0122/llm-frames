//
//  TransitionOrder+Stacking.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The two units of a transition bottom first, the unit `over` names on top.
extension TransitionOrder {
    // MARK: - Property
    var bottomFirst: [TransitionOrder] {
        switch self {
        case .incoming:
            [.outgoing, .incoming]

        case .outgoing:
            [.incoming, .outgoing]
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
