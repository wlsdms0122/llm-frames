//
//  PresetReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

struct PresetReader: Sendable {
    // MARK: - Property
    private let reader = JSONReader()
    private let checker = KeyChecker()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func animation(from data: Data) throws -> AnimationPreset {
        try animation(from: reader.read(data))
    }

    func animation(from value: JSONValue) throws -> AnimationPreset {
        try checker.check(value, as: PresetKeyTable.animation)

        let object = value.objectValue ?? JSONObject()
        return AnimationPreset(
            description: object["description"]?.stringValue ?? "",
            entrance: try animationSpan(object, "entrance", length: "seconds", ease: .easeOut),
            loop: try animationSpan(object, "loop", length: "period", ease: .easeInOut),
            exit: try animationSpan(object, "exit", length: "seconds", ease: .easeIn)
        )
    }

    func transition(from data: Data) throws -> TransitionPreset {
        try transition(from: reader.read(data))
    }

    func transition(from value: JSONValue) throws -> TransitionPreset {
        try checker.check(value, as: PresetKeyTable.transition)

        let object = value.objectValue ?? JSONObject()
        let seconds = object["seconds"]?.numberValue ?? 0
        guard seconds > 0 else {
            throw PresetError.nonPositiveLength(place: Place.root.appending(key: "seconds"), kind: "transition", length: seconds)
        }

        let over = object["over"]?.stringValue.flatMap(TransitionOrder.init(rawValue:)) ?? .incoming
        guard over == .incoming || !object.contains("matte") else {
            throw PresetError.matteOverOutgoing(place: .root)
        }

        let ease = object["ease"].flatMap(Ease.init(value:)) ?? .linear
        return TransitionPreset(
            description: object["description"]?.stringValue ?? "",
            seconds: seconds,
            over: over,
            incoming: try object["incoming"].map { try span($0, place: Place.root.appending(key: "incoming"), ease: ease) },
            outgoing: try object["outgoing"].map { try span($0, place: Place.root.appending(key: "outgoing"), ease: ease) },
            cover: try object["cover"].map { try cover($0, ease: ease) },
            matte: object["matte"].map { matte($0, ease: ease) }
        )
    }

    func filter(from data: Data) throws -> FilterPreset {
        try filter(from: reader.read(data))
    }

    func filter(from value: JSONValue) throws -> FilterPreset {
        try checker.check(value, as: PresetKeyTable.filter)

        let object = value.objectValue ?? JSONObject()
        let objects = (object["ops"]?.arrayValue ?? []).compactMap(\.objectValue)
        for (index, operation) in objects.enumerated() {
            try checkRanges(of: operation, place: Place.root.appending(key: "ops").appending(index: index))
        }

        let operations = objects.map(operation)
        return FilterPreset(description: object["description"]?.stringValue ?? "", operations: operations)
    }

    // MARK: - Private
    private func animationSpan(
        _ object: JSONObject,
        _ name: String,
        length lengthKey: String,
        ease: Ease
    ) throws -> AnimationSpan? {
        guard let value = object[name] else { return nil }

        let place = Place.root.appending(key: name)
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
        ease: Ease
    ) throws -> Cover {
        let object = value.objectValue ?? JSONObject()
        let source: CoverSource = object["media"]?.stringValue.map(CoverSource.media)
            ?? .color(object["color"]?.stringValue ?? "")
        return Cover(source: source, span: try span(value, place: Place.root.appending(key: "cover"), ease: ease))
    }

    private func matte(
        _ value: JSONValue,
        ease: Ease
    ) -> Matte {
        let object = value.objectValue ?? JSONObject()
        return Matte(
            media: object["media"]?.stringValue ?? "",
            softness: object["softness"]?.numberValue ?? 0,
            isInverted: object["invert"]?.boolValue ?? false,
            ease: object["ease"].flatMap(Ease.init(value:)) ?? ease
        )
    }

    private func checkRanges(
        of operation: JSONObject,
        place: Place
    ) throws {
        let name = operation["op"]?.stringValue ?? ""
        for (parameter, range) in FilterRangeTable.ranges(of: name) {
            guard let value = operation[parameter], !range.contains(value) else { continue }

            throw PresetError.parameterOutOfRange(
                place: place.appending(key: parameter),
                kind: name,
                value: value.written,
                range: range.description
            )
        }
    }

    private func operation(_ object: JSONObject) -> FilterOperation {
        let number = { (key: String) in object[key]?.numberValue ?? 0 }
        let numbers = { (key: String) in object[key]?.arrayValue?.compactMap(\.numberValue) ?? [] }

        switch object["op"]?.stringValue {
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
            return .lut(file: object["file"]?.stringValue ?? "", amount: number("amount"))

        case "blur":
            return .blur(radius: number("radius"))

        case "sharpen":
            return .sharpen(amount: number("amount"), radius: number("radius"))

        case "bloom":
            return .bloom(amount: number("amount"), radius: number("radius"), color: object["color"]?.stringValue)

        case "vignette":
            return .vignette(amount: number("amount"), radius: number("radius"))

        case "pixelate":
            return .pixelate(size: number("size"))

        default:
            return .grain(amount: number("amount"), size: number("size"))
        }
    }
}
