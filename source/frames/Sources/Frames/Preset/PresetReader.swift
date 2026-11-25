//
//  PresetReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Reads a preset: checked against its parameter types, then read with every parameter at its default, so a preset
// named without arguments always works, and read again with the arguments each choice passes it.
struct PresetReader: Sendable {
    // MARK: - Property
    private let reader = JSONReader()
    private let checker = KeyChecker()
    private let filler: ParameterFiller
    private let lookReader = LookReader()
    private let merger = LookMerger()

    // MARK: - Initializer
    init() {
        self.filler = ParameterFiller(checker: checker)
    }

    // MARK: - Public
    func animation(from data: Data) throws -> AnimationPreset {
        try animation(from: reader.read(data))
    }

    // `place` is where the preset is written, the top of its file when it is read from one.
    func animation(
        from value: JSONValue,
        place: Place = .root
    ) throws -> AnimationPreset {
        try publishedAnimation(from: value, place: place).defaults
    }

    func publishedAnimation(
        from value: JSONValue,
        place: Place
    ) throws -> PublishedPreset<AnimationPreset> {
        try published(value, as: PresetKeyTable.animation, place: place) { try plainAnimation(from: $0, place: place) }
    }

    func animation(
        _ preset: PublishedPreset<AnimationPreset>,
        instance: PresetInstance
    ) throws -> AnimationPreset {
        try read(preset, instance: instance, kind: "animation choice") { try plainAnimation(from: $0, place: preset.place) }
    }

    func transition(from data: Data) throws -> TransitionPreset {
        try transition(from: reader.read(data))
    }

    // `place` is where the preset is written, the top of its file when it is read from one.
    func transition(
        from value: JSONValue,
        place: Place = .root
    ) throws -> TransitionPreset {
        try publishedTransition(from: value, place: place).defaults
    }

    func publishedTransition(
        from value: JSONValue,
        place: Place
    ) throws -> PublishedPreset<TransitionPreset> {
        try published(value, as: PresetKeyTable.transition, place: place) { try plainTransition(from: $0, place: place) }
    }

    func transition(
        _ preset: PublishedPreset<TransitionPreset>,
        instance: PresetInstance
    ) throws -> TransitionPreset {
        try read(preset, instance: instance, kind: "transition choice") {
            try plainTransition(from: $0, place: preset.place)
        }
    }

    func filter(from data: Data) throws -> FilterPreset {
        try filter(from: reader.read(data))
    }

    // `place` is where the preset is written, the top of its file when it is read from one.
    func filter(
        from value: JSONValue,
        place: Place = .root
    ) throws -> FilterPreset {
        try publishedFilter(from: value, place: place).defaults
    }

    func publishedFilter(
        from value: JSONValue,
        place: Place
    ) throws -> PublishedPreset<FilterPreset> {
        try published(value, as: PresetKeyTable.filter, place: place) { try plainFilter(from: $0, place: place) }
    }

    func filter(
        _ preset: PublishedPreset<FilterPreset>,
        instance: PresetInstance
    ) throws -> FilterPreset {
        let sampled = preset.references.filter { instance.sampled.contains($0.name) }.map(\.place)
        return try read(preset, instance: instance, kind: "filter choice") { value in
            try plainFilter(from: value, place: preset.place, sampled: Set(sampled))
        }
    }

    func publishedAudio(
        from value: JSONValue,
        place: Place
    ) throws -> PublishedPreset<AudioPreset> {
        try published(value, as: PresetKeyTable.audio, place: place) { try plainAudio(from: $0, place: place) }
    }

    func audio(
        _ preset: PublishedPreset<AudioPreset>,
        instance: PresetInstance
    ) throws -> AudioPreset {
        let sampled = preset.references.filter { instance.sampled.contains($0.name) }.map(\.place)
        return try read(preset, instance: instance, kind: AudioFilterKeyTable.kind) { value in
            try plainAudio(from: value, place: preset.place, sampled: Set(sampled))
        }
    }

    // A head preset (FRAMES-11 Heads), which takes no `params`.
    func publishedHead(
        from value: JSONValue,
        place: Place
    ) throws -> PublishedPreset<HeadPreset> {
        try published(value, as: PresetKeyTable.head, place: place) { try plainHead(from: $0, place: place) }
    }

    // An op's parameters in their ranges, a preset's and one written in place alike. A parameter named in `sampled`
    // is one keyframe's value of a parameter two keyframes or more write, so a length or size may be 0 there.
    func checkRanges(
        of operation: JSONObject,
        place: Place,
        sampled: Set<String> = []
    ) throws {
        let name = operation["kind"]?.stringValue ?? ""
        guard case let .object(structure) = LookStructureTable.filterOperation(name) else { return }

        for parameter in structure.keys {
            guard
                case let .leaf(kind) = parameter.structure,
                let declared = ParameterRange(kind: kind),
                let value = operation[parameter.name]
            else {
                continue
            }

            let range = sampled.contains(parameter.name) ? declared.sampled : declared
            guard !range.contains(value) else { continue }

            throw PresetError.parameterOutOfRange(
                place: place.appending(key: parameter.name),
                kind: name,
                value: value.written,
                range: range.description
            )
        }
    }

    // MARK: - Private
    private func published<Preset>(
        _ value: JSONValue,
        as table: ObjectTable,
        place: Place,
        reading: (JSONValue) throws -> Preset
    ) throws -> PublishedPreset<Preset> {
        let references = try checker.check(preset: value, as: table, place: place)
        let parameters = Parameter.declared(in: value)
        let defaults = try filler.values(of: JSONObject(), for: parameters, place: place, kind: ParameterKeyTable.kind)

        return PublishedPreset(
            value: value,
            place: place,
            parameters: parameters,
            references: references,
            defaults: try reading(filler.filling(value, at: references, with: defaults))
        )
    }

    // The arguments are checked against their parameters where the choice writes them. A value they give that its
    // place in the preset does not take stops as the preset's own would, named at the choice.
    private func read<Preset>(
        _ preset: PublishedPreset<Preset>,
        instance: PresetInstance,
        kind: String,
        reading: (JSONValue) throws -> Preset
    ) throws -> Preset {
        guard !instance.arguments.members.isEmpty else { return preset.defaults }

        let values = try filler.values(
            of: instance.arguments,
            for: preset.parameters,
            place: instance.place.appending(key: "args"),
            kind: ChoiceKeyTable.argumentsKind
        )
        do {
            return try reading(filler.filling(preset.value, at: preset.references, with: values))
        } catch {
            throw PresetError.rejectedArguments(place: instance.place, kind: kind, name: instance.name, reason: "\(error)")
        }
    }

    // A preset whose parameters are filled holds plain values, which meet every rule of their places.
    private func plainAnimation(
        from value: JSONValue,
        place: Place
    ) throws -> AnimationPreset {
        try checker.check(value, as: PresetKeyTable.animation, place: place)

        let object = value.objectValue ?? JSONObject()
        return AnimationPreset(
            description: object["description"]?.stringValue ?? "",
            entrance: try animationSpan(object, "entrance", length: "seconds", ease: .easeOut, place: place),
            loop: try animationSpan(object, "loop", length: "period", ease: .easeInOut, place: place),
            exit: try animationSpan(object, "exit", length: "seconds", ease: .easeIn, place: place)
        )
    }

    private func plainTransition(
        from value: JSONValue,
        place: Place
    ) throws -> TransitionPreset {
        try checker.check(value, as: PresetKeyTable.transition, place: place)

        let object = value.objectValue ?? JSONObject()
        let seconds = object["seconds"]?.numberValue ?? 0
        guard seconds > 0 else {
            throw PresetError.nonPositiveLength(place: place.appending(key: "seconds"), kind: "transition", length: seconds)
        }

        let over = object["over"]?.stringValue.flatMap(TransitionOrder.init(rawValue:)) ?? .incoming
        guard over == .incoming || !object.contains("matte") else {
            throw PresetError.matteOverOutgoing(place: place)
        }

        let ease = object["ease"].flatMap(Ease.init(value:)) ?? .linear
        return TransitionPreset(
            description: object["description"]?.stringValue ?? "",
            seconds: seconds,
            over: over,
            audio: object["audio"]?.stringValue.flatMap(CrossfadeCurve.init(rawValue:)) ?? .constantPower,
            incoming: try object["incoming"].map { try span($0, place: place.appending(key: "incoming"), ease: ease) },
            outgoing: try object["outgoing"].map { try span($0, place: place.appending(key: "outgoing"), ease: ease) },
            cover: try object["cover"].map { try cover($0, place: place.appending(key: "cover"), ease: ease) },
            matte: object["matte"].map { matte($0, ease: ease) }
        )
    }

    private func plainHead(
        from value: JSONValue,
        place: Place
    ) throws -> HeadPreset {
        try checker.check(value, as: PresetKeyTable.head, place: place)

        let object = value.objectValue ?? JSONObject()
        guard let head = StrokeHead(written: value) else {
            throw PresetError.invalidHead(place: place, reason: "a head writes its points, length and inset")
        }
        if let refusal = head.refusal {
            throw PresetError.invalidHead(place: place, reason: refusal)
        }

        return HeadPreset(description: object["description"]?.stringValue ?? "", head: head)
    }

    // `sampled` holds the places of the op parameters that sampled arguments fill.
    private func plainFilter(
        from value: JSONValue,
        place: Place,
        sampled: Set<Place> = []
    ) throws -> FilterPreset {
        try checker.check(value, as: PresetKeyTable.filter, place: place)

        let object = value.objectValue ?? JSONObject()
        let objects = (object["ops"]?.arrayValue ?? []).compactMap(\.objectValue)
        for (index, operation) in objects.enumerated() {
            let operationPlace = place.appending(key: "ops").appending(index: index)
            let parameters = operation.keys.filter { sampled.contains(operationPlace.appending(key: $0)) }
            let structure = LookStructureTable.filterOperation(operation["kind"]?.stringValue ?? "")
            try checkRanges(of: operation, place: operationPlace, sampled: Set(parameters))
            try checkRequired(of: operation, as: structure, place: operationPlace)
        }

        let operations = objects.map(operation)
        return FilterPreset(description: object["description"]?.stringValue ?? "", operations: operations)
    }

    // Each op's numbers are in the ranges of its look structure. `sampled` holds the places of the op parameters that
    // sampled arguments fill.
    private func plainAudio(
        from value: JSONValue,
        place: Place,
        sampled: Set<Place> = []
    ) throws -> AudioPreset {
        try checker.check(value, as: PresetKeyTable.audio, place: place)

        let object = value.objectValue ?? JSONObject()
        let operations = (object["ops"]?.arrayValue ?? []).compactMap(\.objectValue)
        for (index, operation) in operations.enumerated() {
            let structure = LookStructureTable.audioOperation(operation["kind"]?.stringValue ?? "")
            let operationPlace = place.appending(key: "ops").appending(index: index)
            try structure.checkDomains(of: .object(operation), place: operationPlace, sampled: sampled)
            try checkRequired(of: operation, as: structure, place: operationPlace)
        }

        return AudioPreset(description: object["description"]?.stringValue ?? "", operations: operations)
    }

    // A preset has no keyframes, so a leaf its op's structure requires, as a blur's `radius`, a compressor's
    // `threshold` or a band's `frequency`, is written in the preset.
    private func checkRequired(
        of operation: JSONObject,
        as structure: ValueStructure,
        place operationPlace: Place
    ) throws {
        do {
            let value = lookReader.value(of: .object(operation), as: structure)
            try merger.checkRequired(in: value, as: structure, place: operationPlace)
        } catch let LookError.missingLeaf(place, key) {
            let kind = place == operationPlace ? operation["kind"]?.stringValue ?? "operation" : "band"
            throw ModelError.missingKey(place: place, kind: kind, keys: [key])
        }
    }

    private func animationSpan(
        _ object: JSONObject,
        _ name: String,
        length lengthKey: String,
        ease: Ease,
        place presetPlace: Place
    ) throws -> AnimationSpan? {
        guard let value = object[name] else { return nil }

        let place = presetPlace.appending(key: name)
        let length = value.objectValue?[lengthKey]?.numberValue ?? 0
        guard length > 0 else {
            throw PresetError.nonPositiveLength(place: place.appending(key: lengthKey), kind: name, length: length)
        }

        return AnimationSpan(length: length, span: try span(value, place: place, ease: ease))
    }

    private func span(
        _ value: JSONValue,
        place: Place,
        ease defaultEase: Ease
    ) throws -> Span {
        let object = value.objectValue ?? JSONObject()
        return Span(
            ease: object["ease"].flatMap(Ease.init(value:)) ?? defaultEase,
            revealFrom: object["revealFrom"]?.stringValue.flatMap(RevealEdge.init(rawValue:)) ?? .left,
            keys: try keys(object["keys"], place: place.appending(key: "keys"))
        )
    }

    private func keys(
        _ value: JSONValue?,
        place: Place
    ) throws -> [SpanKey] {
        let objects = value?.arrayValue?.compactMap(\.objectValue) ?? []
        return try objects.enumerated().map { index, object in
            let t = object["t"]?.numberValue ?? 0
            guard (0...1).contains(t) else {
                throw PresetError.progressOutOfRange(place: place.appending(index: index), t: t)
            }

            let values = MotionProperty.allCases.reduce(into: [MotionProperty: Double]()) { values, property in
                values[property] = object[property.rawValue]?.numberValue
            }
            return SpanKey(t: t, values: values)
        }
    }

    private func cover(
        _ value: JSONValue,
        place: Place,
        ease: Ease
    ) throws -> Cover {
        let object = value.objectValue ?? JSONObject()
        let media = object["media"]
        let source: CoverSource = if object["kind"]?.stringValue == "solid" {
            .color(object["color"]?.stringValue ?? "")
        } else if let page = media?.objectValue {
            .page(page["file"]?.stringValue ?? "", page: Self.page(of: page))
        } else {
            .media(media?.stringValue ?? "")
        }
        return Cover(
            source: source,
            colorSpace: object["colorSpace"]?.stringValue.flatMap(ColorSpace.init(rawValue:)),
            span: try span(value, place: place, ease: ease)
        )
    }

    private func matte(
        _ value: JSONValue,
        ease: Ease
    ) -> Matte {
        let object = value.objectValue ?? JSONObject()
        let page = object["media"]?.objectValue
        return Matte(
            media: page?["file"]?.stringValue ?? object["media"]?.stringValue ?? "",
            page: page.map(Self.page(of:)),
            colorSpace: object["colorSpace"]?.stringValue.flatMap(ColorSpace.init(rawValue:)),
            softness: object["softness"]?.numberValue ?? 0,
            isInverted: object["invert"]?.boolValue ?? false,
            ease: object["ease"].flatMap(Ease.init(value:)) ?? ease
        )
    }

    // The number a page of a PDF names in its `page`, which the key check found a whole number from 1.
    private static func page(of object: JSONObject) -> Int {
        object["page"]?.numberValue.flatMap { Int(exactly: $0) } ?? 1
    }

    private func operation(_ object: JSONObject) -> FilterOperation {
        let number = { (key: String) in object[key]?.numberValue ?? 0 }
        let numbers = { (key: String) in object[key]?.arrayValue?.compactMap(\.numberValue) ?? [] }

        switch object["kind"]?.stringValue {
        case "exposure":
            return .exposure(ev: number("ev"))

        case "contrast":
            return .contrast(amount: number("amount"))

        case "saturation":
            return .saturation(amount: number("amount"))

        case "temperature":
            return .temperature(kelvin: number("kelvin"))

        case "hue":
            return .hue(degrees: number("degrees"))

        case "sepia":
            return .sepia(amount: number("amount"))

        case "levels":
            return .levels(input: numbers("input"), output: numbers("output"))

        case "lut":
            return .lut(
                file: object["file"]?.stringValue ?? "",
                amount: number("amount"),
                space: object["space"]?.stringValue.flatMap(LookUpTableSpace.init) ?? .srgb
            )

        case "blur":
            return .blur(radius: number("radius"))

        case "sharpen":
            return .sharpen(amount: number("amount"), radius: number("radius"))

        case "bloom":
            return .bloom(amount: number("amount"), radius: number("radius"), color: object["color"]?.stringValue)

        case "vignette":
            return .vignette(amount: number("amount"), radius: number("radius"))

        case "displace":
            let offset = numbers("offset")
            return .displace(
                file: object["file"]?.stringValue ?? "",
                amount: number("amount"),
                offset: offset.count == 2 ? Point(x: offset[0], y: offset[1]) : Point(x: 0, y: 0)
            )

        case "pixelate":
            return .pixelate(size: number("size"))

        default:
            return .grain(amount: number("amount"), size: number("size"))
        }
    }
}
