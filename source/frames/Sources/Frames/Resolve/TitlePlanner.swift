//
//  TitlePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans a title. Each run takes the character attributes of its own style with the title's `character` merged over
// them, and the whole title the paragraph attributes of the clip's style with its `paragraph` merged over them, each
// timed by the title's keyframes; the text is set at their static values, its lengths at the length scale of the
// place it is drawn, and its lines break with each run at the largest tracking it takes while the title is seen.
struct TitlePlanner: Sendable {
    // MARK: - Property
    private let fonts: FontFinder
    private let typesetter: Typesetter

    // MARK: - Initializer
    init(
        shaper: any ShapingProvider,
        library: ReferenceLibrary
    ) {
        self.fonts = FontFinder(shaper: shaper, library: library)
        self.typesetter = Typesetter(shaper: shaper)
    }

    // MARK: - Public
    // `looks` plans the title's clip, `visible` is where it is seen in sequence time, and `pack` is the pack of the
    // document it is written in. A run without a style is in the clip's, and a run's style is named at its index in
    // the title's list. A style the theme does not hold stops where it is named. The default line height follows the
    // size of the clip's style with `character` merged over it. `unit` is the unit a title animated by unit plays by,
    // whose characters, under `character`, move alone.
    func plan(
        _ title: ClipTitle,
        looks: ClipLookPlanner,
        pack: String?,
        width: Double?,
        unit: TextUnit?,
        visible: TimeRange,
        theme: MergedTheme
    ) throws -> TitlePlan {
        let place = looks.place.appending(key: "title")
        let kind = looks.kind.label
        try check(title.style, place: looks.place.appending(key: "style"), theme: theme, kind: kind)

        let character = LookStructureTable.character
        let paragraph = LookStructureTable.paragraph
        var faces: [String: [FontFace]] = [:]
        var textRuns: [TextRun] = []
        var characters: [TimedValue] = []
        var trackingSteps: [TimedValue] = []
        for (index, run) in title.runs.enumerated() {
            let runStyle = run.style ?? title.style
            if let named = run.style {
                try check(named, place: place.appending(index: index).appending(key: "style"), theme: theme, kind: kind)
            }

            let merged = try merged(title.character, style: runStyle, looks: looks)
            let written = json(merged, as: character)
            let style = theme.characterStyle(of: written, scale: looks.scale)
            let origin = fontList(of: title, runStyle: runStyle, clip: looks.place, pack: pack, theme: theme, kind: kind)
            let runFaces = try faces[runStyle] ?? fonts.faces(for: style, from: origin)
            faces[runStyle] = runFaces

            let defaults = self.defaults(over: written, face: runFaces[0])
            let timed = try timed(
                merged,
                of: title.character,
                key: "character",
                as: character,
                defaults: defaults,
                looks: looks
            )
            let tracking = trackingTrack(of: timed)
            let range = tracking?.range(over: visible) ?? style.tracking...style.tracking
            characters.append(timed)
            trackingSteps.append(steps(of: tracking, over: style))
            textRuns.append(TextRun(
                text: run.text,
                style: style,
                faces: runFaces,
                widestTracking: range.upperBound,
                isSpacedApart: range.lowerBound != 0 || range.upperBound != 0 || unit == .character
            ))
        }

        let sized = json(try merged(title.character, style: title.style, looks: looks), as: character)
        let merged = try looks.merged(title.paragraph, key: "paragraph", as: paragraph, style: ["styles", title.style])
        // The clip's style keeps the paragraph attributes a title does not write, such as `lines`.
        let style = json(merged, as: paragraph).members.reduce(theme.style(named: title.style)) { style, member in
            style.setting(member.key, to: member.value)
        }
        let size = sized["size"]?.numberValue ?? 0
        let paragraphStyle = theme.paragraphStyle(of: style, size: size, scale: looks.scale)

        return TitlePlan(
            layout: try typesetter.layout(
                textRuns,
                paragraph: paragraphStyle,
                width: width,
                unit: unit,
                place: place,
                kind: kind
            ),
            characters: characters,
            trackingSteps: trackingSteps,
            paragraph: try timed(
                merged,
                of: title.paragraph,
                key: "paragraph",
                as: paragraph,
                defaults: paragraphDefaults(
                    over: json(merged, as: paragraph),
                    lineHeight: theme.defaultLineHeight(of: size)
                ),
                looks: looks
            )
        )
    }

    // MARK: - Private
    // The title's `character` merged over the style `style`.
    private func merged(
        _ character: LookProperty?,
        style: String,
        looks: ClipLookPlanner
    ) throws -> LookValue? {
        try looks.merged(character, key: "character", as: LookStructureTable.character, style: ["styles", style])
    }

    private func timed(
        _ merged: LookValue?,
        of property: LookProperty?,
        key: String,
        as structure: ValueStructure,
        defaults: JSONValue? = nil,
        looks: ClipLookPlanner
    ) throws -> TimedValue {
        guard let merged else { return .off }

        return try looks.timed(property, key: key, over: merged, as: structure, defaults: defaults)
    }

    // What a run's character attributes take where no layer gives them, in theme lengths: the `text` colour, no
    // tracking and no baseline shift; a stroke the `text` colour; a highlight the `background` colour, no padding and
    // no radius; an underline the thickness and the position of the face's `post` underline at the run's size. Each of
    // the last three only where it is on, since a default would turn it on.
    private func defaults(
        over written: JSONObject,
        face: FontFace
    ) -> JSONValue {
        let size = written["size"]?.numberValue ?? 0
        let members = [
            JSONMember(key: "color", value: .string("text")),
            JSONMember(key: "tracking", value: .number(0)),
            JSONMember(key: "baselineShift", value: .number(0)),
            JSONMember(key: "stroke", value: .object(JSONObject(members: [
                JSONMember(key: "color", value: .string("text"))
            ]))),
            JSONMember(key: "highlight", value: .object(JSONObject(members: [
                JSONMember(key: "color", value: .string("background")),
                JSONMember(key: "padding", value: .array([.number(0), .number(0)])),
                JSONMember(key: "radius", value: .number(0))
            ]))),
            JSONMember(key: "underline", value: .object(JSONObject(members: [
                JSONMember(key: "width", value: .number(face.underlineThickness * size)),
                JSONMember(key: "offset", value: .number(face.underlineOffset * size))
            ])))
        ]

        return .object(JSONObject(members: members.filter { member in
            member.value.objectValue == nil || written[member.key]?.objectValue != nil
        }))
    }

    // What the paragraph attributes take where no layer gives them, in theme lengths: `lineHeight`, and a background
    // the `background` colour with no padding and no radius where it is on.
    private func paragraphDefaults(
        over written: JSONObject,
        lineHeight: Double
    ) -> JSONValue {
        let members = [
            JSONMember(key: "lineHeight", value: .number(lineHeight)),
            JSONMember(key: "background", value: .object(JSONObject(members: [
                JSONMember(key: "color", value: .string("background")),
                JSONMember(key: "padding", value: .array([.number(0), .number(0)])),
                JSONMember(key: "radius", value: .number(0))
            ])))
        ]

        return .object(JSONObject(members: members.filter { member in
            member.value.objectValue == nil || written[member.key]?.objectValue != nil
        }))
    }

    // A run's tracking over time, in thousandths of an em.
    private func trackingTrack(of character: TimedValue) -> KeyframeTrack<Double>? {
        guard case let .track(keyframes)? = character["tracking"] else { return nil }

        return KeyframeTrack(keyframes: keyframes.compactMap { keyframe in
            guard case let .number(value) = keyframe.value else { return nil }

            return Keyframe(at: keyframe.at, value: value, ease: keyframe.ease)
        })
    }

    private func steps(
        of tracking: KeyframeTrack<Double>?,
        over style: CharacterStyle
    ) -> TimedValue {
        guard let tracking, tracking.keyframes.contains(where: { $0.value != style.tracking }) else { return .off }

        return .track(tracking.keyframes.map { keyframe in
            let step = (keyframe.value - style.tracking) * style.size / 1000

            return Keyframe(at: keyframe.at, value: .number(step), ease: keyframe.ease)
        })
    }

    private func json(
        _ value: LookValue?,
        as structure: ValueStructure
    ) -> JSONObject {
        value?.json(as: structure)?.objectValue ?? JSONObject()
    }

    // A list the title's `character` writes replaces the style's, so it looks in the pack of the document the title is
    // written in rather than in that of the theme that wrote the style's.
    private func fontList(
        of title: ClipTitle,
        runStyle: String,
        clip: Place,
        pack: String?,
        theme: MergedTheme,
        kind: String
    ) -> FontListOrigin {
        guard title.character?.written?.objectValue?["font"] == nil else {
            return FontListOrigin(place: clip.appending(key: "character").appending(key: "font"), kind: kind, pack: pack)
        }

        return theme.fontList(ofStyle: runStyle)
    }

    private func check(
        _ name: String,
        place: Place,
        theme: MergedTheme,
        kind: String
    ) throws {
        let styles = theme.styleNames
        guard styles.contains(name) else {
            throw ThemeError.unknownStyle(place: place, kind: kind, name: name, styles: styles)
        }
    }
}
