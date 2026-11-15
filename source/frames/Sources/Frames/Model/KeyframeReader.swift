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
    func checkEases(
        in keyframes: JSONValue,
        place: Place
    ) throws {
        let ordered = sorted(keyframes)

        for (position, entry) in ordered.enumerated() where entry.keyframe.contains("ease") {
            let properties = entry.keyframe.keys.filter { !Self.keyframeKeys.contains($0) }
            let isFollowed = ordered[(position + 1)...].contains { later in
                properties.contains(where: later.keyframe.contains)
            }
            guard isFollowed else {
                throw ModelError.easeWithoutFollowingKeyframe(
                    place: place.appending(index: entry.index),
                    properties: properties
                )
            }
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
    private func sorted(_ keyframes: JSONValue) -> [(index: Int, keyframe: JSONObject)] {
        let entries = (keyframes.arrayValue ?? []).enumerated().compactMap { index, value in
            value.objectValue.map { (index: index, keyframe: $0) }
        }

        return entries.sorted { left, right in
            let leftAt = left.keyframe["at"]?.numberValue ?? 0
            let rightAt = right.keyframe["at"]?.numberValue ?? 0
            return leftAt == rightAt ? left.index < right.index : leftAt < rightAt
        }
    }
}
