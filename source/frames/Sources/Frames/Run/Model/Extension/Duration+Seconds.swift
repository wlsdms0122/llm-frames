//
//  Duration+Seconds.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

extension Duration {
    // MARK: - Property
    package var seconds: Double {
        let (seconds, attoseconds) = components

        return Double(seconds) + Double(attoseconds) * 1e-18
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
