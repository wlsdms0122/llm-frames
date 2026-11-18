//
//  ParentFinder.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Finds the clip each parented clip names in the same document: any storyline clip, or a connected or sequence clip
// with a picture. An id that names no clip stops, and so does one that names an audio clip. A chain is followed to its
// end, and one that comes back to a clip already in it stops and names the clips in the cycle.
struct ParentFinder: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `clips` and `written` are the connected and sequence clips in document order.
    func parents(
        of clips: [ClipPlan],
        written: [Clip],
        storyline: [StorylinePlan]
    ) throws -> [ClipParent?] {
        let parents = try clips.indices.map { index in
            try parent(of: written[index], plan: clips[index], clips: clips, storyline: storyline)
        }
        let chain = parents.map { parent -> Int? in
            guard case let .clip(index, _) = parent else { return nil }
            return index
        }
        for index in clips.indices {
            guard let cycle = chain.cycle(from: index) else { continue }

            let clip = clips[cycle[0]]
            throw ResolveError.parentCycle(
                place: clip.place.appending(key: "parent"),
                kind: .clip(clip.kind),
                ids: cycle.map { clips[$0].id ?? clips[$0].place.description }
            )
        }

        return parents
    }

    // MARK: - Private
    private func parent(
        of written: Clip,
        plan: ClipPlan,
        clips: [ClipPlan],
        storyline: [StorylinePlan]
    ) throws -> ClipParent? {
        guard let id = written.parent else { return nil }

        if let index = storyline.firstIndex(where: { $0.id == id }) {
            return .storyline(index: index, id: id)
        }

        let place = written.place.appending(key: "parent")
        guard let index = clips.firstIndex(where: { $0.id == id }) else {
            throw ResolveError.unknownParent(place: place, kind: .clip(plan.kind), id: id)
        }
        guard clips[index].kind != .media(.audio) else {
            throw ResolveError.audioParent(place: place, kind: .clip(plan.kind), id: id)
        }

        return .clip(index: index, id: id)
    }
}
