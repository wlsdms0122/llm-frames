//
//  ClipThemeLayer.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The keys on a clip that stand in for theme values, written as the strongest theme layer.
enum ClipThemeLayer {
    static func layer(
        forClip clip: JSONObject,
        kind: ClipKind
    ) -> JSONValue {
        var layer = JSONObject()

        if let transition = clip["transition"] {
            layer = setting(["defaults", "transition"], to: transition, in: layer)
        }

        if let filter = clip["filter"] {
            layer = setting(["defaults", "filter"], to: filter, in: layer)
        } else if takesNoDefaultFilter(clip, kind: kind) {
            // The clips inside a compound clip or a template instance already took their default filter.
            layer = setting(["defaults", "filter"], to: .string("none"), in: layer)
        }

        if let animation = clip["animation"], let path = animationPath(clip, kind: kind) {
            layer = setting(path, to: animation, in: layer)
        }

        return .object(layer)
    }

    private static func animationPath(
        _ clip: JSONObject,
        kind: ClipKind
    ) -> [String]? {
        switch kind {
        case .title:
            clip["style"]?.stringValue.map { ["defaults", "animation", "title", $0] }

        case .shape:
            ["defaults", "animation", "shape"]

        case .media(.audio), .solid:
            nil

        case .media:
            ["defaults", "animation", "media"]

        case .adjust:
            ["defaults", "animation", "adjust"]
        }
    }

    private static func takesNoDefaultFilter(
        _ clip: JSONObject,
        kind: ClipKind
    ) -> Bool {
        guard case .media = kind else { return false }

        let isTemplate = clip["media"]?.objectValue?.contains("template") ?? false
        return kind == .media(.sequence) || isTemplate
    }

    private static func setting(
        _ path: [String],
        to value: JSONValue,
        in object: JSONObject
    ) -> JSONObject {
        guard let key = path.first else { return object }
        guard path.count > 1 else { return object.setting(key, to: value) }

        let child = object[key]?.objectValue ?? JSONObject()
        return object.setting(key, to: .object(setting(Array(path.dropFirst()), to: value, in: child)))
    }
}
