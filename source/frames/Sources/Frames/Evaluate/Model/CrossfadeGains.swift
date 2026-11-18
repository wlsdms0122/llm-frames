//
//  CrossfadeGains.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

struct CrossfadeGains: Equatable, Sendable {
    // MARK: - Property
    let outgoing: Double
    let incoming: Double

    // MARK: - Initializer
    init(
        outgoing: Double,
        incoming: Double
    ) {
        self.outgoing = outgoing
        self.incoming = incoming
    }

    // MARK: - Public
    // MARK: - Private
}
