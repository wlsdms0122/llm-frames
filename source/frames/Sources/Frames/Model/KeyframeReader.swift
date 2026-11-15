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
            // A later keyframe at the same instant ends a span of no length, which no ease can shape.
            let isFollowed = ordered[(position + 1)...].contains { later in
                later.at > entry.at && properties.contains(where: later.keyframe.contains)
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
    private func sorted(_ keyframes: JSONValue) -> [(index: Int, at: Double, keyframe: JSONObject)] {
        let entries = (keyframes.arrayValue ?? []).enumerated().compactMap { index, value in
            value.objectValue.map { (index: index, at: $0["at"]?.numberValue ?? 0, keyframe: $0) }
        }

        return entries.sorted { left, right in
            left.at == right.at ? left.index < right.index : left.at < right.at
        }
    }
}
