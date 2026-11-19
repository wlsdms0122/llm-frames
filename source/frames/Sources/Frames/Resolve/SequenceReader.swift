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
            theme: object["theme"].map(ThemeReference.init(value:)),
            format: format(object["format"]?.objectValue ?? JSONObject()),
            storyline: storyline,
            clips: clips
        )
    }

    // Media as written at `place`, which keeps its theme when it is a template's argument.
    func source(
        _ value: JSONValue,
        place: Place
    ) -> MediaSource {
        let source = writtenSource(value, place: place)
        guard let theme = argumentThemes.theme(at: place) else { return source }

        return .argument(source, theme: theme)
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
            solid: object["solid"]?.stringValue,
            duration: object["duration"]?.numberValue,
            transition: object["transition"].flatMap { TransitionChoice(value: $0, place: place.appending(key: "transition")) },
            keyframes: keyframes(object["keyframes"]),
            crop: property("crop", of: object, read: CropForm.init(value:)),
            mask: property("mask", of: object, read: ClipMask.masks(in:)),
            trackMatte: object["trackMatte"].flatMap(TrackMatte.init(value:)),
            track: object["track"].flatMap(TrackTarget.init(value:)),
            filter: object["filter"].flatMap { FilterChoice(value: $0, place: place.appending(key: "filter")) },
            anchor: object["anchor"]?.stringValue,
            position: property("position", of: object, read: PositionForm.init(value:)),
            scale: property("scale", of: object, read: \.numberValue),
            rotation: property("rotation", of: object, read: \.numberValue),
            opacity: property("opacity", of: object, read: \.numberValue),
            blend: object["blend"]?.stringValue,
            radius: object["radius"]?.numberValue,
            border: object["border"].flatMap(BorderForm.init(value:)),
            shadow: object["shadow"].flatMap(ShadowForm.init(value:)),
            connected: connected
        )
    }

    private func clip(
        _ object: JSONObject,
        place: Place,
        in clipPlace: ClipPlace
    ) -> Clip {
        let keyframes = keyframes(object["keyframes"])

        return Clip(
            place: place,
            id: object["id"]?.stringValue,
            clipPlace: clipPlace,
            content: content(of: object, place: place),
            at: object["at"].flatMap(window),
            lane: object["lane"]?.numberValue.flatMap { Int(exactly: $0) },
            parent: object["parent"]?.stringValue,
            placement: object["placement"]?.stringValue,
            anchor: object["anchor"]?.stringValue,
            animation: object["animation"].flatMap { AnimationChoice(value: $0, place: place.appending(key: "animation")) },
            keyframes: keyframes,
            area: property("area", of: object, read: AreaForm.init(value:)),
            position: property("position", of: object, read: PositionForm.init(value:)),
            crop: property("crop", of: object, read: CropForm.init(value:)),
            mask: property("mask", of: object, read: ClipMask.masks(in:)),
            trackMatte: object["trackMatte"].flatMap(TrackMatte.init(value:)),
            track: object["track"].flatMap(TrackTarget.init(value:)),
            width: object["width"]?.numberValue,
            height: object["height"]?.numberValue,
            conform: object["conform"]?.stringValue.flatMap(Conform.init),
            radius: object["radius"]?.numberValue,
            border: object["border"].flatMap(BorderForm.init(value:)),
            shadow: object["shadow"].flatMap(ShadowForm.init(value:)),
            opacity: property("opacity", of: object, read: \.numberValue),
            scale: property("scale", of: object, read: \.numberValue),
            rotation: property("rotation", of: object, read: \.numberValue),
            blend: object["blend"]?.stringValue,
            filter: filter(of: object, place: place)
        )
    }

    // An adjustment clip's `adjust` is its filter choice.
    private func filter(
        of object: JSONObject,
        place: Place
    ) -> FilterChoice? {
        let key = object.contains("adjust") ? "adjust" : "filter"

        return object[key].flatMap { FilterChoice(value: $0, place: place.appending(key: key)) }
    }

    private func content(
        of object: JSONObject,
        place: Place
    ) -> ClipContent {
        if let media = object["media"] {
            return .media(self.media(media, of: object, place: place.appending(key: "media")))
        }
        if let kind = object["shape"]?.stringValue.flatMap(ShapeKind.init(rawValue:)) {
            return .shape(shape(kind, of: object))
        }
        if let title = object["title"] {
            return .title(runs: TitleRun.runs(in: title), style: object["style"]?.stringValue ?? "")
        }

        return .adjust
    }

    private func shape(
        _ kind: ShapeKind,
        of clip: JSONObject
    ) -> ClipShape {
        ClipShape(
            kind: kind,
            style: clip["style"]?.stringValue,
            width: property("width", of: clip, read: \.numberValue),
            height: property("height", of: clip, read: \.numberValue),
            points: property("points", of: clip) { value in
                value.arrayValue.map { elements in elements.compactMap(PositionForm.init(value:)) }
            },
            isClosed: clip["closed"]?.boolValue ?? false,
            radius: property("radius", of: clip, read: \.numberValue),
            outset: clip["outset"]?.numberValue,
            fill: clip["fill"],
            stroke: clip["stroke"],
            trim: property("trim", of: clip) { value in
                let ends = value.arrayValue?.compactMap(\.numberValue) ?? []
                return ends.count == 2 ? Trim(start: ends[0], end: ends[1]) : nil
            },
            shadow: clip["shadow"]
        )
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
            loop: clip["loop"]?.boolValue,
            timeRemap: property("timeRemap", of: clip, read: \.numberValue),
            volume: property("volume", of: clip, read: \.numberValue),
            pan: property("pan", of: clip, read: \.numberValue),
            fadeIn: clip["fadeIn"]?.numberValue,
            fadeOut: clip["fadeOut"]?.numberValue
        )
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
        return .compound(sequence(from: value, place: place))
    }

    private func format(_ object: JSONObject) -> SequenceFormat {
        SequenceFormat(
            fps: object["fps"]?.numberValue,
            size: object["size"].flatMap(formatSize),
            conform: object["conform"]?.stringValue.flatMap(Conform.init),
            background: object["background"]?.stringValue
        )
    }

    // `[w, h]`, or `{"fit": "content", "margin": m}` with a margin of 0 when it writes none.
    private func formatSize(_ value: JSONValue) -> FormatSize? {
        if let object = value.objectValue {
            return .content(margin: object["margin"].map(Margin.init(value:)) ?? .zero)
        }

        let size = value.arrayValue?.compactMap(\.numberValue) ?? []
        return size.count == 2 ? .fixed(Size(width: size[0], height: size[1])) : nil
    }

    // A property no keyframe names is its static value, or nil when it has none.
    private func property<Value>(
        _ key: String,
        of object: JSONObject,
        read: (JSONValue) -> Value?
    ) -> PropertyValue<Value>? {
        if let value = object[key] {
            return read(value).map { .value($0) }
        }

        let keyframes = (object["keyframes"]?.arrayValue ?? []).enumerated().compactMap { index, element in
            element.objectValue.flatMap { keyframe -> PropertyKeyframe<Value>? in
                guard let at = keyframe["at"]?.numberValue, let value = keyframe[key].flatMap(read) else { return nil }

                return PropertyKeyframe(
                    index: index,
                    at: at,
                    value: value,
                    ease: keyframe["ease"].flatMap(Ease.init(value:)) ?? .linear
                )
            }
        }
        guard !keyframes.isEmpty else { return nil }

        return .keyframes(keyframes)
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
