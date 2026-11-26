//
//  MemorySize.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

import Foundation

// A run's memory limit in bytes, with the form it is written in: `<number>MB` or `<number>GB`, the number decimal
// digits with an optional fraction, in units of 2^20 and 2^30 bytes, at least 1 MB (FRAMES-30 The option).
package struct MemorySize: Equatable, Sendable {
    // MARK: - Property
    package static let megabyte = 1 << 20
    package static let gigabyte = 1 << 30

    // A limit that grants every holder all it asks, for an engine used with no run's limit, as by a test.
    package static let unlimited = MemorySize(bytes: .max, written: "unlimited")

    package let bytes: Int
    package let written: String

    // MARK: - Initializer
    // Nil for text not of the form, or under 1 MB.
    package init?(_ text: String) {
        guard let match = text.wholeMatch(of: #/([0-9]+(?:\.[0-9]+)?)(MB|GB)/#), let number = Double(match.1) else {
            return nil
        }

        let unit = match.2 == "GB" ? Self.gigabyte : Self.megabyte
        let bytes = (number * Double(unit)).rounded(.down)
        guard bytes >= Double(Self.megabyte), bytes < Double(Int.max) else { return nil }

        self.bytes = Int(bytes)
        self.written = text
    }

    // `fraction` of `physical` bytes, rounded down to a whole MB.
    package init(
        fraction: Double,
        of physical: UInt64
    ) {
        let megabytes = Int((Double(physical) * fraction / Double(Self.megabyte)).rounded(.down))
        self.bytes = megabytes * Self.megabyte
        self.written = megabytes % 1024 == 0 ? "\(megabytes / 1024)GB" : "\(megabytes)MB"
    }

    private init(
        bytes: Int,
        written: String
    ) {
        self.bytes = bytes
        self.written = written
    }

    // MARK: - Public
    // MARK: - Private
}
