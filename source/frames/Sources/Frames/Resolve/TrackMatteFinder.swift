//
//  TrackMatteFinder.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Checks the clip each track matte names in the same document (FRAMES-11): a connected or sequence media clip, title
// or shape. An id that names no clip stops, and so does one that names a storyline clip, an adjustment clip or an
// audio clip. A clip in a nested document has its own ids, so naming it from outside names no clip. A chain of track
// mattes is followed to its end, and one that comes back to a clip already in it stops and names the clips in the
// cycle. A clip used as a matte by two clips is fine.
struct TrackMatteFinder: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `links` are every clip of the document, in document order.
    func check(_ links: [TrackMatteLink]) throws {
        let mattes = try links.map { link -> Int? in
            guard let matte = link.trackMatte else { return nil }

            let place = link.place.appending(key: "trackMatte").appending(key: "clip")
            guard let index = links.firstIndex(where: { $0.id == matte.clip }) else {
                throw ResolveError.unknownTrackMatte(place: place, kind: link.kind, id: matte.clip)
            }
            if let refusal = links[index].refusal {
                throw ResolveError.trackMatteKind(place: place, kind: link.kind, id: matte.clip, matte: refusal)
            }

            return index
        }

        for index in links.indices {
            guard let cycle = mattes.cycle(from: index) else { continue }

            let link = links[cycle[0]]
            throw ResolveError.trackMatteCycle(
                place: link.place.appending(key: "trackMatte").appending(key: "clip"),
                kind: link.kind,
                ids: cycle.map { links[$0].id ?? links[$0].place.description }
            )
        }
    }

    // MARK: - Private
}
