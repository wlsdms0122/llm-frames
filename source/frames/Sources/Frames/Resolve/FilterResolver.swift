//
//  FilterResolver.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Resolves a filter choice, merged over the theme's default, to the timed filter a clip draws: an entry for each
// entry of the choice, the ops of its preset or the one op written in place, and its `mix`. Each preset is read with
// the arguments the choice writes, and again with each keyframe's over them, and an op in place is checked by the same
// rules, so a stop names the choice or the keyframe. A preset's op parameter that an argument fills takes that argument's keyframes, and the rest of its
// parameters are one keyframe at the clip's instant. Lengths are output pixels at the planner's scale, a LUT and a
// displacement map are their absolute paths, and colours are values in `theme`.
struct FilterResolver: Sendable {
    // MARK: - Property
    private let presets: any PresetProvider
    private let values: PresetValueResolver
    private let lookReader = LookReader()
    private let reader = PresetReader()

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.presets = presets
        self.values = PresetValueResolver(library: library)
    }

    // MARK: - Public
    // `merged` is the choice the clip applies, nil for none, and `place` where the layer that gives its entries
    // writes it. `key` is the clip's key, which its keyframes write.
    func timed(
        _ property: LookProperty?,
        merged: JSONValue?,
        key: String,
        place: Place,
        looks: ClipLookPlanner,
        theme: MergedTheme,
        kind: PlaceKind
    ) throws -> TimedValue {
        guard let merged, merged != .string("none") else { return .off }

        let isList = merged.arrayValue != nil
        let entries = merged.arrayValue ?? [merged]
        var published: [String: PublishedPreset<FilterPreset>] = [:]
        for (index, entry) in entries.enumerated() {
            guard let instance = PresetInstance(value: entry, place: isList ? place.appending(index: index) : place)
            else {
                continue
            }

            published[instance.name] = try preset(instance, theme: theme, kind: kind)
        }

        let structure = LookStructureTable.filter(
            presets: published.keys.sorted().compactMap { name in published[name].map { (name, $0.parameters) } }
        )
        try checkRanges(of: property, entries: entries, isList: isList, place: place, looks: looks, key: key, theme: theme)
        let timed = try looks.timed(property, key: key, over: lookReader.value(of: merged, as: structure), as: structure)

        let elements = if case let .list(elements) = timed { elements } else { [timed] }

        return .list(try elements.enumerated().map { index, element in
            try self.entry(
                element,
                published: published,
                place: isList ? place.appending(index: index) : place,
                looks: looks,
                kind: kind
            )
        })
    }

    // MARK: - Private
    // A preset is checked with the arguments the choice writes, a colour, a LUT and a displacement map it names included.
    private func preset(
        _ instance: PresetInstance,
        theme: MergedTheme,
        kind: PlaceKind
    ) throws -> PublishedPreset<FilterPreset> {
        guard let preset = try presets.filter(instance), let published = try presets.publishedFilter(named: instance.name)
        else {
            throw ResolveError.unknownPreset(place: instance.place, kind: kind, presetKind: "filter", name: instance.name)
        }

        for operation in preset.operations {
            _ = try values.operation(operation, theme: theme, place: instance.place, kind: kind)
        }

        return published
    }

    // An entry's op parameters are checked by the rules of a preset's ops, statically for an op written in place and
    // with each keyframe's values over the merged ones, so a keyframe's stop names the keyframe and the clip. A value two
    // keyframes or more write is one end of a change, so a length or size it fills may be 0 there; one a single
    // keyframe writes is checked as a static value.
    private func checkRanges(
        of property: LookProperty?,
        entries: [JSONValue],
        isList: Bool,
        place: Place,
        looks: ClipLookPlanner,
        key: String,
        theme: MergedTheme
    ) throws {
        let keyframes = property?.keyframes ?? []
        for (index, entry) in entries.enumerated() {
            let operation = entry.objectValue.flatMap { $0["op"] == nil ? nil : $0 }
            let instance = PresetInstance(value: entry, place: looks.place)
            if let operation {
                try reader.checkRanges(of: operation, place: isList ? place.appending(index: index) : place)
            }

            let written = keyframes.compactMap { keyframe -> (place: Place, values: JSONObject)? in
                let values = keyframe.value.arrayValue ?? [keyframe.value]
                guard index < values.count, let object = values[index].objectValue else { return nil }

                let given = operation == nil
                    ? object["args"]?.objectValue ?? JSONObject()
                    : JSONObject(members: object.members.filter { $0.key != "op" && $0.key != "mix" })
                guard !given.members.isEmpty else { return nil }

                let place = looks.place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: key)
                return (keyframe.value.arrayValue == nil ? place : place.appending(index: index), given)
            }
            let names = written.flatMap { $0.values.members.map(\.key) }
            let sampled = Set(names.filter { name in names.filter { $0 == name }.count > 1 })
            for (place, values) in written {
                let given = values.members.filter { $0.value != .null }
                if let operation {
                    let merged = given.reduce(operation) { merged, member in merged.setting(member.key, to: member.value) }
                    try reader.checkRanges(of: merged, place: place, sampled: sampled)
                } else if let instance {
                    let arguments = given.reduce(instance.arguments) { merged, member in
                        merged.setting(member.key, to: member.value)
                    }
                    let keyframed = PresetInstance(name: instance.name, arguments: arguments, place: place, sampled: sampled)
                    _ = try preset(keyframed, theme: theme, kind: looks.kind)
                }
            }
        }
    }

    private func entry(
        _ value: TimedValue,
        published: [String: PublishedPreset<FilterPreset>],
        place: Place,
        looks: ClipLookPlanner,
        kind: PlaceKind
    ) throws -> TimedValue {
        guard case let .form(name, body) = value, case let .object(members) = body else { return .off }

        let mix = body["mix"] ?? .off
        let operations: [TimedValue]
        if name.hasPrefix("op:") {
            let parameters = members.filter { $0.key != "mix" }
            operations = [.form(name, .object(try parameters.map { member in
                try file(member, operation: name, place: place, kind: kind)
            }))]
        } else if let preset = published[String(name.dropFirst("preset:".count))] {
            operations = try self.operations(of: preset, arguments: body["args"], place: place, looks: looks, kind: kind)
        } else {
            operations = []
        }

        return .object([TimedMember(key: "ops", value: .list(operations)), TimedMember(key: "mix", value: mix)])
    }

    // Each op of the preset with its arguments in place, in the order its parameters are declared.
    private func operations(
        of preset: PublishedPreset<FilterPreset>,
        arguments: TimedValue?,
        place: Place,
        looks: ClipLookPlanner,
        kind: PlaceKind
    ) throws -> [TimedValue] {
        let objects = preset.value.objectValue?["ops"]?.arrayValue?.compactMap(\.objectValue) ?? []

        return try objects.enumerated().map { index, object in
            let name = object["op"]?.stringValue ?? ""
            let form = "op:" + name
            guard case let .object(structure) = LookStructureTable.filterOperation(name) else { return .off }

            let opPlace = preset.place.appending(key: "ops").appending(index: index)
            let parameters = try structure.keys.compactMap { parameter -> TimedMember? in
                guard let value = object[parameter.name], case let .leaf(leaf) = parameter.structure else { return nil }

                let parameterPlace = opPlace.appending(key: parameter.name)
                let timed = try self.parameter(
                    value,
                    kind: leaf,
                    references: preset.references.filter { reference in
                        reference.place.file == parameterPlace.file
                            && reference.place.components.starts(with: parameterPlace.components)
                    },
                    at: parameterPlace,
                    arguments: arguments,
                    place: place,
                    looks: looks
                )
                return try file(TimedMember(key: parameter.name, value: timed), operation: form, place: place, kind: kind)
            }
            return .form(form, .object(parameters))
        }
    }

    // A parameter an argument fills takes the argument's keyframes. One of numbers whose elements arguments fill is
    // timed element by element, each element its own keyframe list, so every argument keeps the eases it is written
    // with.
    private func parameter(
        _ value: JSONValue,
        kind: LeafKind,
        references: [ParameterReference],
        at parameterPlace: Place,
        arguments: TimedValue?,
        place: Place,
        looks: ClipLookPlanner
    ) throws -> TimedValue {
        let length = kind.isLength ? looks.scale : 1
        if let reference = references.first(where: { $0.place == parameterPlace }) {
            return scaled(arguments?[reference.name] ?? .off, by: length)
        }
        guard !references.isEmpty, let elements = value.arrayValue else {
            return try looks.timed(value, kind: kind, place: place)
        }

        return .list(try elements.enumerated().map { index, element in
            let elementPlace = parameterPlace.appending(index: index)
            guard let reference = references.first(where: { $0.place == elementPlace }) else {
                let elementKind = LeafKind(form: .number, domain: kind.domain, isLength: kind.isLength)
                return try looks.timed(element, kind: elementKind, place: place)
            }

            return scaled(arguments?[reference.name] ?? .off, by: length)
        })
    }

    // A LUT or a displacement map named by its pack or its path is its absolute path.
    private func file(
        _ member: TimedMember,
        operation: String,
        place: Place,
        kind: PlaceKind
    ) throws -> TimedMember {
        guard member.key == "file", case let .fixed(.string(name)) = member.value else { return member }

        let path = switch operation {
        case "op:lut":
            try values.lutFile(name, place: place, kind: kind)

        case "op:displace":
            try values.displacementMap(name, place: place, kind: kind)

        default:
            name
        }
        return TimedMember(key: "file", value: .fixed(.string(path)))
    }

    private func scaled(
        _ value: TimedValue,
        by scale: Double
    ) -> TimedValue {
        guard scale != 1, case let .track(keyframes) = value else { return value }

        return .track(keyframes.map { keyframe in
            guard case let .number(number) = keyframe.value else { return keyframe }

            return Keyframe(at: keyframe.at, value: .number(number * scale), ease: keyframe.ease)
        })
    }
}
