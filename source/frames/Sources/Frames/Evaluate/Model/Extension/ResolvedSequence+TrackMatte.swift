//
//  ResolvedSequence+TrackMatte.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The track mattes of a resolved sequence (FRAMES-11): which clips are used as mattes, and so draw no item of their
// own, and the chain a track matte starts, which resolve has checked ends.
extension ResolvedSequence {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Whether a track matte of the sequence names the clip.
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
