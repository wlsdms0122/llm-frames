//
//  MaskPlanner.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Plans a clip's masks as timed values: the clip's `mask` is its own layer with the structure its keyframes give, and
// no style lies below it, so the merged value is that layer; `shape` must be given there. Each leaf is then timed over
// it, an area, a position or a point given by text found in `picture` at the media time of the leaf's own instant, a
// clip area kept for evaluation where the masks take one, and `feather` and a clip area's padding theme lengths times
// `lengthScale`. A mask written alone is read as a list of one, and a stop names it as
// the document wrote it, `mask.<key>` for a mask alone and `mask[i].<key>` in a list.
struct MaskPlanner: Sendable {
    // MARK: - Property
    private let reader = LookReader()
    private let merger = LookMerger()
    private let builder = TimedValueBuilder()

    private let finder: GeometryFinder
    private let place: Place
    private let kind: PlaceKind
    private let clock: TimeMap
    private let instant: Double
    private let lengthScale: Double

    // MARK: - Initializer
    init(
        finder: GeometryFinder,
        place: Place,
        kind: PlaceKind,
        clock: TimeMap,
        instant: Double,
        lengthScale: Double
    ) {
        self.finder = finder
        self.place = place
        self.kind = kind
        self.clock = clock
        self.instant = instant
        self.lengthScale = lengthScale
    }

    // MARK: - Public
    // `textStop` is the stop for a text form where the clip's masks are not in a picture that can be searched, and
    // `takesClipArea` whether the masks are in the space the clip is drawn in, where a clip area names a box drawn
    // there. Anywhere else a clip area stops as an area searched in a picture.
    func masks(
        _ property: LookProperty?,
        in picture: Picture,
        pictureClock: PictureClock,
        textStop: ((Place) -> ResolveError)? = nil,
        takesClipArea: Bool = false
    ) throws -> [FoundMask]? {
        guard let property else { return nil }

        let structure = LookStructureTable.mask
        let lookPlace = LookPlace(clip: place, key: "mask")
        // A clip that writes no `mask` has its masks alone where every keyframe writes them alone.
        let isWrittenAlone = property.written.map { $0.objectValue != nil }
            ?? property.keyframes.allSatisfy { $0.value.objectValue != nil }
        let aloneKeyframes = Set(property.keyframes.filter { $0.value.objectValue != nil }.map(\.index))
        let placed = { (place: Place) in
            self.pointPlaced(
                self.placed(place, isWrittenAlone: isWrittenAlone, aloneKeyframes: aloneKeyframes),
                in: property
            )
        }

        let written = property.written.map { reader.value(of: listed($0), as: structure) }
        let keyframes = property.keyframes.map { keyframe in
            PropertyKeyframe(
                index: keyframe.index,
                at: clock.sequenceTime(ofClipTime: keyframe.at),
                value: reader.value(of: listed(keyframe.value), as: structure),
                ease: keyframe.ease
            )
        }

        var textTimes: [Int: [MaskLeaf: Set<Double>]] = [:]
        var staticLeaves: [Int: Set<MaskLeaf>] = [:]
        let timed: TimedValue
        do {
            let own = try builder.ownLayer(written: written, keyframes: keyframes, as: structure, place: lookPlace)
            guard let merged = own else { return nil }

            // A mask's `shape` is static, and a path's vertex may take its point from its keyframes.
            try merger.checkRequired(in: merged, keyframes: keyframes, as: structure, place: lookPlace)

            timed = try builder.timed(
                merged,
                written: written,
                keyframes: keyframes,
                as: structure,
                instant: instant,
                place: lookPlace,
                leaf: { json, leafKind, source in
                    let found = try leaf(
                        json,
                        kind: leafKind,
                        source: source,
                        in: picture,
                        pictureClock: pictureClock,
                        place: placed(source.written),
                        textStop: textStop,
                        takesClipArea: takesClipArea
                    )
                    if let index = found.index, let text = found.text {
                        textTimes[index, default: [:]][text, default: []].insert(source.time)
                    }
                    if source.keyframe == nil, let geometry = geometryLeaf(at: source.place.path.components) {
                        staticLeaves[geometry.index, default: []].insert(geometry.leaf)
                    }

                    return found.value
                }
            )
        } catch let LookError.missingLeaf(place, key) {
            throw ResolveError.missingLookLeaf(place: placed(place), kind: kind, key: key, layer: nil)
        } catch let error as LookError {
            throw error.placed(placed)
        }

        guard case let .list(masks) = timed else { return nil }

        return masks.enumerated().compactMap { index, mask in
            ResolvedMask(timed: mask).map { mask in
                FoundMask(mask: mask, textTimes: textTimes[index] ?? [:], staticLeaves: staticLeaves[index] ?? [])
            }
        }
    }

    // MARK: - Private
    // The index of the mask that holds a leaf at the path and the geometry leaf it is, nil for a leaf of no geometry.
    private func geometryLeaf(at path: [PlaceComponent]) -> (index: Int, leaf: MaskLeaf)? {
        guard path.count >= 2, case let .index(index, _) = path[0], case let .key(key) = path[1] else { return nil }

        switch key {
        case "area":
            return (index, .area)

        case "width":
            return (index, .width)

        case "height":
            return (index, .height)

        case "position":
            return (index, .position)

        case "radius":
            return (index, .radius)

        case "points":
            guard path.count >= 4, case let .index(vertex, _) = path[2], case let .key(leaf) = path[3] else {
                return nil
            }

            switch leaf {
            case "vertex":
                return (index, .point(vertex))

            case "inTangent":
                return (index, .inTangent(vertex))

            case "outTangent":
                return (index, .outTangent(vertex))

            default:
                return nil
            }

        default:
            return nil
        }
    }

    // One leaf's value, the index of the mask that holds it, and the geometry leaf a text form gave.
    private func leaf(
        _ json: JSONValue,
        kind leafKind: LeafKind,
        source: LeafSource,
        in picture: Picture,
        pictureClock: PictureClock,
        place: Place,
        textStop: ((Place) -> ResolveError)?,
        takesClipArea: Bool
    ) throws -> (value: LeafValue, index: Int?, text: MaskLeaf?) {
        let path = source.place.path.components
        guard path.count >= 2, case let .index(index, _) = path[0], case let .key(key) = path[1] else {
            return (number(json, kind: leafKind), nil, nil)
        }

        let mediaTime = pictureClock.mediaTime(atSequenceTime: source.time)
        let position: PositionForm?
        let maskLeaf: MaskLeaf
        switch key {
        case "area":
            guard let form = AreaForm(value: json) else { return (number(json, kind: leafKind), index, nil) }

            if form.isFoundByText, let textStop {
                throw textStop(place)
            }
            if takesClipArea, let area = ClipArea(form: form, lengthScale: lengthScale) {
                return (.area(area), index, nil)
            }
            let rectangle = try finder.area(form, in: picture, at: mediaTime, place: place, kind: kind.label).rectangle
            return (
                .numbers([rectangle.x, rectangle.y, rectangle.width, rectangle.height]),
                index,
                form.isFoundByText ? .area : nil
            )

        case "position":
            position = PositionForm(value: json)
            maskLeaf = .position

        case "points":
            guard path.count >= 4, case let .index(vertex, _) = path[2], path[3] == .key("vertex") else {
                return (number(json, kind: leafKind), index, nil)
            }

            position = PositionForm(value: json)
            maskLeaf = .point(vertex)

        default:
            return (number(json, kind: leafKind), index, nil)
        }

        guard let position else { return (number(json, kind: leafKind), index, nil) }

        if position.isFoundByText, let textStop {
            throw textStop(place)
        }
        if
            takesClipArea,
            case let .area(form, name) = position,
            let area = ClipArea(form: form, lengthScale: lengthScale)
        {
            return (.point(area, name: name), index, nil)
        }
        let point = try finder.point(position, in: picture, at: mediaTime, place: place, kind: kind.label)
        return (.numbers([point.x, point.y]), index, position.isFoundByText ? maskLeaf : nil)
    }

    private func number(
        _ json: JSONValue,
        kind leafKind: LeafKind
    ) -> LeafValue {
        let length = leafKind.isLength ? lengthScale : 1
        guard case .numbers = leafKind.form else { return .number((json.numberValue ?? 0) * length) }

        return .numbers((json.arrayValue ?? []).compactMap(\.numberValue).map { $0 * length })
    }

    private func listed(_ json: JSONValue) -> JSONValue {
        json.objectValue == nil ? json : .array([json])
    }

    // The place of a vertex's point as the document writes it, which `PathKeyTable` gives from the vertex its layer
    // writes at `mask.points[i]` or `mask[m].points[i]`, statically or in a keyframe. The look's structure names every
    // point at its vertex's `vertex`.
    private func pointPlaced(
        _ written: Place,
        in property: LookProperty
    ) -> Place {
        let below = Array(written.components.dropFirst(place.components.count))
        let layer: JSONValue?
        let path: ArraySlice<PlaceComponent>
        switch (below.first, below.dropFirst().first) {
        case (.key("mask"), _):
            layer = property.written
            path = below.dropFirst()

        case let (.key("keyframes"), .index(index, _)):
            layer = property.keyframes.first { $0.index == index }?.value
            path = below.dropFirst(3)

        default:
            return written
        }
        let mask: Int? = if case let .index(index, _) = path.first { index } else { nil }
        let leaf = Array(path.dropFirst(mask == nil ? 0 : 1))
        guard
            leaf.count == 3,
            leaf[0] == .key("points"),
            case let .index(index, _) = leaf[1],
            leaf[2] == .key("vertex"),
            let masks = layer.map(listed)?.arrayValue,
            masks.indices.contains(mask ?? 0),
            let vertices = masks[mask ?? 0].objectValue?["points"]?.arrayValue,
            vertices.indices.contains(index)
        else {
            return written
        }

        return PathKeyTable.place(
            ofPointOf: vertices[index],
            at: Place(file: written.file, components: Array(written.components.dropLast()))
        )
    }

    // The place as the document writes it: the index of a mask written alone, statically or in a keyframe, is left out.
    private func placed(
        _ written: Place,
        isWrittenAlone: Bool,
        aloneKeyframes: Set<Int>
    ) -> Place {
        let start = place.components.count
        var components = written.components
        let at = { (offset: Int) -> PlaceComponent? in
            components.indices.contains(start + offset) ? components[start + offset] : nil
        }

        let element: Int? = switch (at(0), at(1), at(2)) {
        case (.key("mask"), _, _) where isWrittenAlone:
            start + 1

        case let (.key("keyframes"), .index(index, _), .key("mask")) where aloneKeyframes.contains(index):
            start + 3

        default:
            nil
        }
        guard let element, components.indices.contains(element), case .index = components[element] else {
            return written
        }

        components.remove(at: element)
        return Place(file: written.file, components: components)
    }
}
