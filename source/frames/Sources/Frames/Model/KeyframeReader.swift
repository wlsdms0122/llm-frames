//
//  KeyframeReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Reads checked keyframes into one track per property. Each property joins only the keyframes that name it.
struct KeyframeReader: Sendable {
    // MARK: - Property
    private static let keyframeKeys: Set<String> = ["at", "ease"]

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // A keyframe's `ease` shapes the span towards the next keyframe of each leaf it writes, so one of its leaves must
    // be written again at a later instant: a span opens at the last keyframe of an instant, as in KeyframeTrack.
    func checkEases(
        in keyframes: JSONValue,
        place: Place
    ) throws {
        let ordered = sorted(keyframes)

        for (position, entry) in ordered.enumerated() where entry.keyframe.contains("ease") {
            let written = leaves(of: entry.keyframe)
            let opensSpan = written.contains { leaf in
                let next = ordered[(position + 1)...].first { later in leaves(of: later.keyframe).contains { $0.isLeaf(of: leaf) } }
                guard let next else { return false }

                return next.at > entry.at
            }
            guard opensSpan else {
                throw ModelError.easeWithoutFollowingKeyframe(
                    place: place.appending(index: entry.index),
                    leaves: written
                )
            }
        }
    }

    // The leaves a keyframe writes, each by its path below the keyframe. A look key, which is timed leaf by leaf, is
    // walked into through its objects and lists of objects, and any other value is one leaf, so a point, a colour,
    // `true` and `null` are each one. Every other key is timed as one value, a crop or a list of points too, so it is
    // one leaf.
    func leaves(of keyframe: JSONObject) -> [Place] {
        keyframe.members.filter { !Self.keyframeKeys.contains($0.key) }.flatMap { member in
            let place = Place.root.appending(key: member.key)
            return ClipKeyTable.lookKeys.contains(member.key) ? leaves(of: member.value, at: place) : [place]
        }
    }

    func track<Value: Interpolable>(
        of property: String,
        in keyframes: JSONValue,
        read: (JSONValue) throws -> Value
    ) rethrows -> KeyframeTrack<Value>? {
        let joined = try sorted(keyframes).compactMap { entry -> Keyframe<Value>? in
            guard let value = entry.keyframe[property], let at = entry.keyframe["at"]?.numberValue else { return nil }

            let ease = entry.keyframe["ease"].flatMap(Ease.init(value:)) ?? .linear
            return Keyframe(at: at, value: try read(value), ease: ease)
        }
        guard !joined.isEmpty else { return nil }

        return KeyframeTrack(keyframes: joined)
    }

    // MARK: - Private
    private func leaves(
        of value: JSONValue,
        at place: Place
    ) -> [Place] {
        switch value {
        case let .object(object):
            return object.members.flatMap { member in leaves(of: member.value, at: place.appending(key: member.key)) }

        case let .array(elements) where !elements.isEmpty && elements.allSatisfy({ $0.objectValue != nil }):
            return elements.enumerated().flatMap { index, element in leaves(of: element, at: place.appending(index: index)) }

        default:
            return [place]
        }
    }

    private func sorted(_ keyframes: JSONValue) -> [(index: Int, at: Double, keyframe: JSONObject)] {
        let entries = (keyframes.arrayValue ?? []).enumerated().compactMap { index, value in
            value.objectValue.map { (index: index, at: $0["at"]?.numberValue ?? 0, keyframe: $0) }
        }

        return entries.sorted { left, right in
            left.at == right.at ? left.index < right.index : left.at < right.at
        }
    }
}
