//
//  UnitOrder.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// The order a title's units start in when it is animated by unit. Each unit takes a rank from its index among the
// units in reading order and the unit count alone, and its entrance and exit are spaced by its rank where they would be
// by its index.
enum UnitOrder: String, CaseIterable, Equatable, Sendable {
    case forward
    case backward
    case center
    case edges
    case random

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The rank of each of `count` units, by index in reading order. Units of one rank start together.
    func ranks(count: Int) -> [Int] {
        let indices = Array(0..<max(count, 0))
        switch self {
        case .forward:
            return indices

        case .backward:
            return indices.reversed()

        case .center:
            return indices.map { Self.centerRank(of: $0, count: count) }

        case .edges:
            let largest = Self.centerRank(of: 0, count: count)
            return indices.map { largest - Self.centerRank(of: $0, count: count) }

        case .random:
            return Self.shuffled(indices, seed: UInt64(indices.count))
        }
    }

    // MARK: - Private
    // The distance of `index` from (count - 1) / 2, rounded down, computed in halves so it stays an integer.
    private static func centerRank(
        of index: Int,
        count: Int
    ) -> Int {
        abs(2 * index - (count - 1)) / 2
    }

    // A Fisher-Yates shuffle from the last position down to 1, swapping position k with position next() mod (k + 1).
    private static func shuffled(
        _ values: [Int],
        seed: UInt64
    ) -> [Int] {
        var generator = SplitMix64(seed: seed)
        var values = values
        for k in values.indices.dropFirst().reversed() {
            let other = Int(generator.next() % UInt64(k + 1))
            values.swapAt(k, other)
        }

        return values
    }
}
