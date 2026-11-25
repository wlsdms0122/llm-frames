//
//  AudioFilterResolver.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Resolves a clip's audio filter to the timed list of entries `{ops, mix}` its sound is processed with: a preset's ops
// with its arguments in place, or the one op written in place, each op with its defaults written and an impulse
// response its absolute path. A static op parameter is checked against its range where the clip writes it, and a
// keyframed one by timing. A preset is read with the arguments the choice writes, and again with each keyframe's over
// them, so a stop names the choice or the keyframe.
struct AudioFilterResolver: Sendable {
    // MARK: - Property
    static let key = "audioFilter"

    private let presets: any PresetProvider
    private let values: PresetValueResolver

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.presets = presets
        self.values = PresetValueResolver(library: library)
    }

    // MARK: - Public
    func timed(
        _ property: LookProperty?,
        looks: ClipLookPlanner
    ) throws -> TimedValue {
        guard let property else { return .off }

        let place = looks.place.appending(key: Self.key)
        let isList = property.written?.arrayValue != nil
        let entries = property.written.map { $0.arrayValue ?? [$0] } ?? []
        var published: [String: PublishedPreset<AudioPreset>] = [:]
        for (index, entry) in entries.enumerated() {
            let entryPlace = isList ? place.appending(index: index) : place
            if let instance = PresetInstance(value: entry, place: entryPlace) {
                published[instance.name] = try preset(instance, kind: looks.kind)
            } else {
                let name = entry.objectValue?["kind"]?.stringValue ?? ""
                try LookStructureTable.audioOperation(name, mixed: true).checkDomains(of: entry, place: entryPlace)
            }
        }
        try checkArguments(of: property, entries: entries, isList: isList, looks: looks)

        let structure = LookStructureTable.audioFilter(
            presets: published.keys.sorted().compactMap { name in
                published[name].map { (name, $0.parameters, staticArguments(of: $0)) }
            }
        )
        let timed = try looks.timed(property, key: Self.key, as: structure)
        let elements = if case let .list(elements) = timed { elements } else { [timed] }

        return .list(try elements.enumerated().map { index, element in
            let entryPlace = isList ? place.appending(index: index) : place
            return try entry(element, published: published, place: entryPlace, looks: looks)
        })
    }

    // MARK: - Private
    private func preset(
        _ instance: PresetInstance,
        kind: PlaceKind
    ) throws -> PublishedPreset<AudioPreset> {
        guard try presets.audio(instance) != nil, let published = try presets.publishedAudio(named: instance.name) else {
            throw ResolveError.unknownPreset(
                place: instance.place,
                kind: kind,
                preset: try presets.unknown(.audio, named: instance.name)
            )
        }

        return published
    }

    // The arguments a static op parameter of the preset reads, as a limiter's `lookahead`, which no keyframe may move.
    private func staticArguments(of preset: PublishedPreset<AudioPreset>) -> Set<String> {
        let objects = preset.value.objectValue?["ops"]?.arrayValue?.compactMap(\.objectValue) ?? []
        let places = objects.enumerated().flatMap { index, object -> [Place] in
            guard case let .object(structure) = LookStructureTable.audioOperation(object["kind"]?.stringValue ?? "") else {
                return []
            }

            let place = preset.place.appending(key: "ops").appending(index: index)
            return structure.keys.compactMap { key, child in
                guard case let .leaf(kind) = child, !kind.isTimed else { return nil }

                return place.appending(key: key)
            }
        }

        return Set(preset.references.filter { places.contains($0.place) }.map(\.name))
    }

    // A preset entry's arguments are checked by reading the preset with each keyframe's over the choice's. An argument
    // two keyframes or more write is one end of a change, so its value is checked as its samples are.
    private func checkArguments(
        of property: LookProperty,
        entries: [JSONValue],
        isList: Bool,
        looks: ClipLookPlanner
    ) throws {
        for (index, entry) in entries.enumerated() {
            guard let instance = PresetInstance(value: entry, place: looks.place) else { continue }

            let written = property.keyframes.compactMap { keyframe -> (place: Place, arguments: JSONObject)? in
                let values = keyframe.value.arrayValue ?? [keyframe.value]
                guard index < values.count, let arguments = values[index].objectValue?["args"]?.objectValue else {
                    return nil
                }

                let place = looks.place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: Self.key)
                return (isList ? place.appending(index: index) : place, arguments)
            }
            let names = written.flatMap { $0.arguments.members.map(\.key) }
            let sampled = Set(names.filter { name in names.filter { $0 == name }.count > 1 })
            for (place, arguments) in written {
                let given = arguments.members.filter { $0.value != .null }
                let merged = given.reduce(instance.arguments) { merged, member in
                    merged.setting(member.key, to: member.value)
                }
                let keyframed = PresetInstance(name: instance.name, arguments: merged, place: place, sampled: sampled)
                _ = try preset(keyframed, kind: looks.kind)
            }
        }
    }

    // An op's `mix` belongs to its entry, so the entry is its ops and the `mix` they are heard with. `place` is where
    // the entry is written.
    private func entry(
        _ value: TimedValue,
        published: [String: PublishedPreset<AudioPreset>],
        place: Place,
        looks: ClipLookPlanner
    ) throws -> TimedValue {
        guard case let .form(name, .object(members)) = value else { return value }

        let operations: [TimedValue]
        if name.hasPrefix("kind:") {
            operations = [.form(name, .object(members.filter { $0.key != "mix" }))]
        } else if let preset = published[String(name.dropFirst("preset:".count))] {
            let arguments = members.first { $0.key == "args" }?.value
            operations = try self.operations(of: preset, arguments: arguments, looks: looks)
        } else {
            operations = []
        }

        let resolved = try operations.map { try file(of: $0, place: place, kind: looks.kind) }

        return .object([
            TimedMember(key: "ops", value: .list(resolved)),
            TimedMember(key: "mix", value: members.first { $0.key == "mix" }?.value ?? .off)
        ])
    }

    private func operations(
        of preset: PublishedPreset<AudioPreset>,
        arguments: TimedValue?,
        looks: ClipLookPlanner
    ) throws -> [TimedValue] {
        let objects = preset.value.objectValue?["ops"]?.arrayValue?.compactMap(\.objectValue) ?? []

        return try objects.enumerated().map { index, object in
            let name = object["kind"]?.stringValue ?? ""
            let body = try timed(
                .object(object),
                as: LookStructureTable.audioOperation(name),
                at: preset.place.appending(key: "ops").appending(index: index),
                references: preset.references,
                arguments: arguments,
                looks: looks
            )
            return .form("kind:" + name, body)
        }
    }

    // A `convolve`'s impulse response named by its pack or its path is its absolute path.
    private func file(
        of operation: TimedValue,
        place: Place,
        kind: PlaceKind
    ) throws -> TimedValue {
        guard case let .form(name, .object(members)) = operation, name == "kind:convolve" else { return operation }

        return .form(name, .object(try members.map { member in
            guard member.key == "file", case let .fixed(.string(reference)) = member.value else { return member }

            let path = try values.impulseResponse(reference, place: place, kind: kind)
            return TimedMember(key: "file", value: .fixed(.string(path)))
        }))
    }

    // A preset's op with its arguments in place: a parameter an argument fills takes the argument's keyframes, and
    // every other leaf is held, a default written where the op leaves it out.
    private func timed(
        _ value: JSONValue,
        as structure: ValueStructure,
        at place: Place,
        references: [ParameterReference],
        arguments: TimedValue?,
        looks: ClipLookPlanner
    ) throws -> TimedValue {
        if let reference = references.first(where: { $0.place == place }) {
            return arguments?[reference.name] ?? .off
        }

        switch (value, structure) {
        case let (.object(object), .object(structure)):
            return .object(try structure.keys.compactMap { key, child in
                guard let member = object[key] ?? structure.plain[key] else { return nil }

                let timed = try self.timed(
                    member,
                    as: child,
                    at: place.appending(key: key),
                    references: references,
                    arguments: arguments,
                    looks: looks
                )
                return TimedMember(key: key, value: timed)
            })

        case let (.object(object), .choice):
            guard let form = structure.form(of: object), let body = structure.structure(ofForm: form.name) else {
                return .fixed(value)
            }

            let timed = try self.timed(
                .object(form.body),
                as: body,
                at: place,
                references: references,
                arguments: arguments,
                looks: looks
            )
            return .form(form.name, timed)

        case let (.array(elements), .list(element)):
            return .list(try elements.enumerated().map { index, value in
                try timed(
                    value,
                    as: element,
                    at: place.appending(index: index),
                    references: references,
                    arguments: arguments,
                    looks: looks
                )
            })

        case let (_, .leaf(kind)):
            return try looks.timed(value, kind: kind, place: looks.place.appending(key: Self.key))

        default:
            return .fixed(value)
        }
    }
}
