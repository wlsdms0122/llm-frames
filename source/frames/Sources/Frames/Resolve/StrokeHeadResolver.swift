//
//  StrokeHeadResolver.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Writes the heads a merged stroke names as values (FRAMES-11 Heads, FRAMES-19 No names): an end whose `preset` is
// `none` is off, and any other end is its head preset's `points`, `length` and `inset` beside the end's timed
// `scale`. A name that finds no head preset stops.
struct StrokeHeadResolver: Sendable {
    // MARK: - Property
    // The end that draws no head.
    static let none = "none"

    private let presets: any PresetProvider

    // MARK: - Initializer
    init(presets: any PresetProvider) {
        self.presets = presets
    }

    // MARK: - Public
    // `place` is the stroke's, where a name that finds nothing is reported.
    func pinned(
        _ stroke: TimedValue,
        place: Place,
        kind: PlaceKind
    ) throws -> TimedValue {
        guard case let .object(members) = stroke else { return stroke }

        return .object(try members.map { member in
            guard ["start", "end"].contains(member.key) else { return member }

            let value = try pinned(end: member.value, place: place.appending(key: member.key), kind: kind)
            return TimedMember(key: member.key, value: value)
        })
    }

    // MARK: - Private
    private func pinned(
        end: TimedValue,
        place: Place,
        kind: PlaceKind
    ) throws -> TimedValue {
        guard case let .fixed(.string(name))? = end["preset"], name != Self.none else { return .off }
        guard let head = try presets.head(named: name) else {
            throw ResolveError.unknownPreset(place: place, kind: kind, preset: try presets.unknown(.head, named: name))
        }

        let values = head.members.map { TimedMember(key: $0.key, value: .fixed($0.value)) }
        return .object(values + [end["scale"].map { TimedMember(key: "scale", value: $0) }].compactMap { $0 })
    }
}
