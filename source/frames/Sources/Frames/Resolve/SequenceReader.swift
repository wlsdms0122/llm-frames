//
//  SequenceReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Reads a sequence document that passed the key tables into model types, once, with every clip's place.
// `argumentThemes` are the themes media a template instance was given keeps, by its place.
struct SequenceReader: Sendable {
    // MARK: - Property
    private static let keyframeKeys: Set<String> = ["at", "ease"]

    private let argumentThemes: ArgumentThemeTable

    // MARK: - Initializer
    init(argumentThemes: ArgumentThemeTable = .empty) {
        self.argumentThemes = argumentThemes
    }

    // MARK: - Public
    func sequence(
        from document: JSONValue,
        place: Place = .root
    ) -> SequenceDocument {
        let object = document.objectValue ?? JSONObject()
        let storylinePlace = place.appending(key: "storyline")
        let storyline = (object["storyline"]?.arrayValue ?? []).enumerated().map { index, element in
            storylineClip(element.objectValue ?? JSONObject(), place: elementPlace(storylinePlace, index, element))
        }
        let clipsPlace = place.appending(key: "clips")
        let clips = (object["clips"]?.arrayValue ?? []).enumerated().map { index, element in
            clip(element.objectValue ?? JSONObject(), place: elementPlace(clipsPlace, index, element), in: .sequence)
        }

        return SequenceDocument(
            place: place,
            theme: object["theme"].flatMap(theme),
            format: SequenceFormat(fps: object["format"]?.objectValue?["fps"]?.numberValue),
            storyline: storyline,
            clips: clips
        )
    }

    // MARK: - Private
    private func storylineClip(
        _ object: JSONObject,
        place: Place
    ) -> StorylineClip {
        let connectedPlace = place.appending(key: "connected")
        let connected = (object["connected"]?.arrayValue ?? []).enumerated().map { index, element in
            clip(
                element.objectValue ?? JSONObject(),
                place: elementPlace(connectedPlace, index, element),
                in: .connected
            )
        }

        return StorylineClip(
            place: place,
            id: object["id"]?.stringValue,
            media: object["media"].map { media($0, of: object, place: place.appending(key: "media")) },
            duration: object["duration"]?.numberValue,
            transition: object["transition"].flatMap(TransitionChoice.init(value:)),
            keyframes: keyframes(object["keyframes"]),
            connected: connected
        )
    }

    private func clip(
        _ object: JSONObject,
        place: Place,
        in clipPlace: ClipPlace
    ) -> Clip {
        let keyframes = keyframes(object["keyframes"])
        let hasKeyframedArea = keyframes.contains { $0.properties.contains("area") }

        return Clip(
            place: place,
            id: object["id"]?.stringValue,
            clipPlace: clipPlace,
            content: content(of: object, place: place),
            at: object["at"].flatMap(window),
            lane: object["lane"]?.numberValue.flatMap { Int(exactly: $0) },
            hasParent: object["parent"]?.boolValue ?? false,
            hasPlacement: object.contains("placement"),
            hasArea: object.contains("area") || hasKeyframedArea,
            animation: object["animation"].flatMap(AnimationChoice.init(value:)),
            keyframes: keyframes
        )
    }

    private func content(
        of object: JSONObject,
        place: Place
    ) -> ClipContent {
        if let media = object["media"] {
            return .media(self.media(media, of: object, place: place.appending(key: "media")))
        }
        if let shape = object["shape"]?.stringValue {
            return .shape(shape)
        }
        if object.contains("title") {
            return .title(style: object["style"]?.stringValue ?? "")
        }

        return .adjust
    }

    private func media(
        _ value: JSONValue,
        of clip: JSONObject,
        place: Place
    ) -> ClipMedia {
        ClipMedia(
            source: source(value, place: place),
            in: clip["in"]?.numberValue,
            out: clip["out"]?.numberValue,
            speed: clip["speed"]?.numberValue,
            loop: clip["loop"]?.boolValue ?? false
        )
    }

    private func source(
        _ value: JSONValue,
        place: Place
    ) -> MediaSource {
        let source = writtenSource(value, place: place)
        guard let theme = argumentThemes.theme(at: place) else { return source }

        return .argument(source, theme: theme)
    }

    private func writtenSource(
        _ value: JSONValue,
        place: Place
    ) -> MediaSource {
        guard let object = value.objectValue else { return .file(value.stringValue ?? "") }

        if let template = object["template"]?.stringValue {
            return .template(
                name: template,
                arguments: object["args"]?.objectValue ?? JSONObject(),
                passedOnThemes: argumentThemes.passedOnThemes(inArgumentsAt: place.appending(key: "args"))
            )
        }
        if let directory = object["imageSequence"]?.stringValue, let fps = object["fps"]?.numberValue {
            return .imageSequence(directory: directory, fps: fps)
        }
        guard MediaKind(document: value) == .sequence else { return .document(object) }

        return .compound(sequence(from: value, place: place))
    }

    private func theme(_ value: JSONValue) -> ThemeReference {
        guard let name = value.stringValue else { return .object(value) }

        return .named(name)
    }

    private func window(_ value: JSONValue) -> ClipWindow? {
        if let start = value.numberValue {
            return .start(start)
        }

        let bounds = value.arrayValue?.compactMap(\.numberValue) ?? []
        guard bounds.count == 2 else { return nil }

        return .range(start: bounds[0], end: bounds[1])
    }

    private func keyframes(_ value: JSONValue?) -> [KeyframeInstant] {
        (value?.arrayValue ?? []).enumerated().compactMap { index, element in
            guard let keyframe = element.objectValue, let at = keyframe["at"]?.numberValue else { return nil }

            return KeyframeInstant(
                index: index,
                at: at,
                properties: keyframe.keys.filter { !Self.keyframeKeys.contains($0) }
            )
        }
    }

    private func elementPlace(
        _ place: Place,
        _ index: Int,
        _ element: JSONValue
    ) -> Place {
        place.appending(index: index, id: element.objectValue?["id"]?.stringValue)
    }
}
