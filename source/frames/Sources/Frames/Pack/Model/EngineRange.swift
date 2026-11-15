//
//  EngineRange.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The versions of frames a pack is written for, `^major[.minor[.patch]]`: the version written, with missing parts 0,
// up to the next major version.
struct EngineRange: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let lowest: [Int]

    // MARK: - Initializer
    init?(_ text: String) {
        guard text.hasPrefix("^") else { return nil }

        let parts = text.dropFirst().split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { part in part.allSatisfy(\.isASCII) ? Int(part) : nil }
        guard (1...3).contains(parts.count), numbers.count == parts.count, numbers.allSatisfy({ $0 >= 0 }) else {
            return nil
        }

        self.text = text
        self.lowest = numbers + Array(repeating: 0, count: 3 - numbers.count)
    }

    // MARK: - Public
    func contains(_ version: String) -> Bool {
        let numbers = version.split(separator: ".").compactMap { Int($0) }
        guard numbers.count == 3 else { return false }

        return numbers[0] == lowest[0] && !numbers.lexicographicallyPrecedes(lowest)
    }

    // MARK: - Private
}
