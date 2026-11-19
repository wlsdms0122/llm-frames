//
//  AudioFilterResolver.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Resolves a clip's audio filter to the timed list of entries `{ops, mix}` its sound is processed with, each the one
// op written in place with its defaults written. A static parameter is checked against its range where the clip writes
// it; a keyframed one is checked by timing.
struct AudioFilterResolver: Sendable {
    // MARK: - Property
    static let key = "audioFilter"

    // MARK: - Initializer
    // MARK: - Public
    func timed(
        _ property: LookProperty?,
        looks: ClipLookPlanner
    ) throws -> TimedValue {
        guard let property else { return .off }

        let place = looks.place.appending(key: Self.key)
        if let written = property.written {
            try check(written, place: place, kind: looks.kind)
        }

        let timed = try looks.timed(property, key: Self.key, as: LookStructureTable.audioFilter)
        let entries = if case let .list(entries) = timed { entries } else { [timed] }

        return .list(entries.map(entry))
    }

    // MARK: - Private
    // Each entry is an op written in place, in its range.
    private func check(
        _ written: JSONValue,
        place: Place,
        kind: PlaceKind
    ) throws {
        let isList = written.arrayValue != nil
        for (index, entry) in (written.arrayValue ?? [written]).enumerated() {
            let entryPlace = isList ? place.appending(index: index) : place
            guard let object = entry.objectValue, let name = object["op"]?.stringValue else {
                let name = entry.stringValue ?? entry.objectValue?["preset"]?.stringValue ?? ""
                throw ResolveError.unknownPreset(place: entryPlace, kind: kind, presetKind: "audio", name: name)
            }

            try checkRange(entry, as: LookStructureTable.audioOperation(name, mixed: true), place: entryPlace)
        }
    }

    private func checkRange(
        _ value: JSONValue,
        as structure: ValueStructure,
        place: Place
    ) throws {
        switch (value, structure) {
        case let (.object(object), .object(structure)):
            for (key, memberStructure) in structure.keys {
                guard let member = object[key] else { continue }

                try checkRange(member, as: memberStructure, place: place.appending(key: key))
            }

        case let (.array(elements), .list(element)):
            for (index, value) in elements.enumerated() {
                try checkRange(value, as: element, place: place.appending(index: index))
            }

        case let (.number(number), .leaf(kind)):
            guard kind.domain.isSeen(number) else { throw LookError.outsideDomain(place: place, value: number) }

        default:
            break
        }
    }

    // An op's `mix` belongs to its entry, so the entry is its op and the `mix` it is heard with.
    private func entry(_ value: TimedValue) -> TimedValue {
        guard case let .form(name, .object(members)) = value else { return value }

        let operation = TimedValue.form(name, .object(members.filter { $0.key != "mix" }))
        return .object([
            TimedMember(key: "ops", value: .list([operation])),
            TimedMember(key: "mix", value: members.first { $0.key == "mix" }?.value ?? .off)
        ])
    }
}
