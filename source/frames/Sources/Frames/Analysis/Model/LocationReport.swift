//
//  LocationReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `locate` prints: every item under a point of the output, topmost first.
package struct LocationReport: Equatable, Sendable {
    // MARK: - Property
    package let hits: [LocationHit]

    // MARK: - Initializer
    init(hits: [LocationHit]) {
        self.hits = hits
    }

    // MARK: - Public
    // MARK: - Private
}
