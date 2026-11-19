//
//  TitlePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans a title. Each run takes the character attributes of its own style with the title's `character` merged over
// them, and the whole title the paragraph attributes of the clip's style with its `paragraph` merged over them, each
// timed by the title's keyframes; the text is set at their static values, its lengths at the length scale of the
// place it is drawn.
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
    // `looks` plans the title's clip, and `pack` is the pack of the document it is written in. A run without a style is
    // in the clip's, and a run's style is named at its index in the title's list. A style the theme does not hold
    // stops where it is named. The default line height follows the size of the clip's style with `character` merged
    // over it.
    func plan(
        _ title: ClipTitle,
        looks: ClipLookPlanner,
        pack: String?,
        width: Double?,
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
        for (index, run) in title.runs.enumerated() {
            let runStyle = run.style ?? title.style
            if let named = run.style {
                try check(named, place: place.appending(index: index).appending(key: "style"), theme: theme, kind: kind)
            }

            let merged = try merged(title.character, style: runStyle, looks: looks)
            let style = theme.characterStyle(of: json(merged, as: character), scale: looks.scale)
            let origin = fontList(of: title, runStyle: runStyle, clip: looks.place, pack: pack, theme: theme, kind: kind)
            let runFaces = try faces[runStyle] ?? fonts.faces(for: style, from: origin)
            faces[runStyle] = runFaces

            textRuns.append(TextRun(text: run.text, style: style, faces: runFaces))
            characters.append(try timed(merged, of: title.character, key: "character", as: character, looks: looks))
        }

        let sized = json(try merged(title.character, style: title.style, looks: looks), as: character)
        let merged = try looks.merged(title.paragraph, key: "paragraph", as: paragraph, style: ["styles", title.style])
        // The clip's style keeps the paragraph attributes a title does not write, such as `lines`.
        let style = json(merged, as: paragraph).members.reduce(theme.style(named: title.style)) { style, member in
            style.setting(member.key, to: member.value)
        }
        let paragraphStyle = theme.paragraphStyle(
            of: style,
            size: sized["size"]?.numberValue ?? 0,
            scale: looks.scale
        )

        return TitlePlan(
            layout: try typesetter.layout(textRuns, paragraph: paragraphStyle, width: width, place: place, kind: kind),
            characters: characters,
            paragraph: try timed(merged, of: title.paragraph, key: "paragraph", as: paragraph, looks: looks)
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
        looks: ClipLookPlanner
    ) throws -> TimedValue {
        guard let merged else { return .off }

        return try looks.timed(property, key: key, over: merged, as: structure)
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
