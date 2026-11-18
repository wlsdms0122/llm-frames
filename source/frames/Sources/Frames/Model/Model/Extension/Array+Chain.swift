//
//  Array+Chain.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Links of chains among a document's clips, a parent chain or a track matte chain: each element is the index of the
// next clip on its clip's chain, nil where the chain ends.
extension Array where Element == Int? {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The cycle the chain from `start` comes back into, as indices, or nil when the chain ends. The cycle starts at its
    // clip that comes first, so every clip on it gives the same cycle.
    func cycle(from start: Int) -> [Int]? {
        var chain = [start]
        var next = self[start]
        while let index = next {
            if let repeated = chain.firstIndex(of: index) {
                let cycle = Array<Int>(chain[repeated...])
                let first = cycle.firstIndex(of: cycle.min() ?? index) ?? 0
                return Array<Int>(cycle[first...] + cycle[..<first])
            }

            chain.append(index)
            next = self[index]
        }

        return nil
    }

    // MARK: - Private
}
