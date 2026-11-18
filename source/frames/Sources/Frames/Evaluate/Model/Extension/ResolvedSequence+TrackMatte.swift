//
//  ResolvedSequence+TrackMatte.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Resolution rejects a track matte cycle, so the chain a track matte starts ends.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func isMatte(_ clip: ResolvedClip) -> Bool {
        guard let id = clip.id else { return false }

        return storyline.contains { $0.trackMatte?.clip == id } || clips.contains { $0.trackMatte?.clip == id }
    }

    // Each track matte of the chain from `trackMatte` with the clip it names, the clip's own matte first.
    func matteChain(from trackMatte: TrackMatte?) -> [(trackMatte: TrackMatte, clip: ResolvedClip)] {
        var chain: [(trackMatte: TrackMatte, clip: ResolvedClip)] = []
        var next = trackMatte
        while let trackMatte = next, let clip = clips.first(where: { $0.id == trackMatte.clip }) {
            chain.append((trackMatte, clip))
            next = clip.trackMatte
        }

        return chain
    }

    // MARK: - Private
}
