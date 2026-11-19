//
//  ClipAreaFinder.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Checks the clip each clip area names in the same document: a connected or sequence media clip, title or shape, the
// clips a track matte may name, drawn in the space of the clip that writes the area (both with one parent or none) or
// that clip's own parent. A clip whose box depends on itself through clip areas stops, naming the clips in the cycle.
// A storyline clip is placed in output pixels by the storyline, so it takes no clip area.
struct ClipAreaFinder: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `clips` and `links` are the connected and sequence clips in document order, `storyline` the storyline clips.
    func check(
        storyline: [StorylineClip],
        clips: [ClipPlan],
        written: [Clip],
        links: [TrackMatteLink],
        storylineLinks: [TrackMatteLink]
    ) throws {
        for (clip, link) in zip(storyline, storylineLinks) {
            if let reference = references(position: clip.position, place: clip.place).first {
                throw ResolveError.clipAreaOnStoryline(place: reference.place, kind: link.kind)
            }
        }

        let named = try written.indices.map { index in
            try references(of: written[index]).map { reference in
                try self.named(reference, by: index, clips: clips, links: links, storylineLinks: storylineLinks)
            }
        }

        var finished: Set<Int> = []
        for index in written.indices {
            var path: [Int] = []
            guard let cycle = cycle(from: index, named: named, path: &path, finished: &finished) else { continue }

            // The cycle starts at its clip that comes first, and its place is that clip's area naming the next.
            let start = cycle.firstIndex(of: cycle.min() ?? index) ?? 0
            let ordered = Array(cycle[start...] + cycle[..<start])
            let next = ordered[1 % ordered.count]
            let place = zip(references(of: written[ordered[0]]), named[ordered[0]]).first { $0.1 == next }?.0.place
            throw ResolveError.clipAreaCycle(
                place: place ?? written[ordered[0]].place,
                kind: links[ordered[0]].kind,
                ids: ordered.map { links[$0].id ?? links[$0].place.description }
            )
        }
    }

    // MARK: - Private
    // The index of the clip a reference names, checked.
    private func named(
        _ reference: ClipAreaReference,
        by index: Int,
        clips: [ClipPlan],
        links: [TrackMatteLink],
        storylineLinks: [TrackMatteLink]
    ) throws -> Int {
        let link = links[index]
        if let storyline = storylineLinks.first(where: { $0.id == reference.clip }) {
            throw ResolveError.clipAreaKind(
                place: reference.place,
                kind: link.kind,
                id: reference.clip,
                named: storyline.refusal ?? .storyline
            )
        }
        guard let named = links.firstIndex(where: { $0.id == reference.clip }) else {
            throw ResolveError.unknownClipArea(place: reference.place, kind: link.kind, id: reference.clip)
        }
        if let refusal = links[named].refusal {
            throw ResolveError.clipAreaKind(place: reference.place, kind: link.kind, id: reference.clip, named: refusal)
        }

        let parent = clips[index].parent?.id
        let namedParent = clips[named].parent?.id
        guard parent == namedParent || parent == reference.clip else {
            throw ResolveError.clipAreaAcrossSpaces(
                place: reference.place,
                kind: link.kind,
                id: reference.clip,
                parent: parent,
                namedParent: namedParent
            )
        }

        return named
    }

    // The cycle a walk from `index` comes back into, depth first; `finished` holds the clips whose every walk ends.
    private func cycle(
        from index: Int,
        named: [[Int]],
        path: inout [Int],
        finished: inout Set<Int>
    ) -> [Int]? {
        if let repeated = path.firstIndex(of: index) {
            return Array(path[repeated...])
        }
        guard !finished.contains(index) else { return nil }

        path.append(index)
        for next in named[index] {
            if let cycle = cycle(from: next, named: named, path: &path, finished: &finished) {
                return cycle
            }
        }
        path.removeLast()
        finished.insert(index)

        return nil
    }

    // Every clip area a clip writes in its `area`, `position` and a path's `points`, statically and in keyframes.
    private func references(of clip: Clip) -> [ClipAreaReference] {
        geometryReferences(of: clip) + references(position: clip.position, place: clip.place)
    }

    private func geometryReferences(of clip: Clip) -> [ClipAreaReference] {
        let area = clip.area.map { area in
            entries(area, key: "area", place: clip.place).compactMap { form, place in
                form.clip.map { ClipAreaReference(place: place, clip: $0) }
            }
        } ?? []
        let points: [ClipAreaReference] = if case let .shape(shape) = clip.content, let points = shape.points {
            entries(points, key: "points", place: clip.place).flatMap { forms, place in
                forms.enumerated().compactMap { index, form in
                    form.clip.map { clip in
                        ClipAreaReference(place: place.appending(index: index).appending(key: "area"), clip: clip)
                    }
                }
            }
        } else {
            []
        }

        return area + points
    }

    private func references(
        position: PropertyValue<PositionForm>?,
        place: Place
    ) -> [ClipAreaReference] {
        guard let position else { return [] }

        return entries(position, key: "position", place: place).compactMap { form, place in
            form.clip.map { ClipAreaReference(place: place.appending(key: "area"), clip: $0) }
        }
    }

    // A property's static value or each keyframe's, with the place that writes it.
    private func entries<Value>(
        _ property: PropertyValue<Value>,
        key: String,
        place: Place
    ) -> [(Value, Place)] {
        switch property {
        case let .value(value):
            [(value, place.appending(key: key))]

        case let .keyframes(keyframes):
            keyframes.map { keyframe in
                (keyframe.value, place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: key))
            }
        }
    }
}
