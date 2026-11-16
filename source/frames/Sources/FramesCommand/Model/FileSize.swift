//
//  FileSize.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// A file's size as a person reads it: bytes below a kilobyte, and above that SI units with one decimal, as `840 B`,
// `3.4 kB` and `12.3 MB`.
struct FileSize: Equatable, CustomStringConvertible, Sendable {
    // MARK: - Property
    private static let units = ["kB", "MB", "GB", "TB", "PB"]

    let bytes: Int64

    var description: String {
        guard bytes >= 1000 else { return "\(bytes) B" }

        var value = Double(bytes) / 1000
        var unit = 0
        // A value that rounds to 1000.0 is written in the next unit, so `999.96 kB` reads `1.0 MB`.
        while (value * 10).rounded() >= 10_000, unit + 1 < Self.units.count {
            value /= 1000
            unit += 1
        }

        return "\(String(format: "%.1f", value)) \(Self.units[unit])"
    }

    // MARK: - Initializer
    init(bytes: Int64) {
        self.bytes = bytes
    }

    // MARK: - Public
    // MARK: - Private
}
