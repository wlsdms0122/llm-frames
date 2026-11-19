//
//  ThemeTypesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `scale` is the length scale of the place the text is drawn, which multiplies each style's lengths. Each run takes its
// own style's character attributes with the title's `character` merged over them, and the whole title the paragraph
// attributes of the clip's style with its `paragraph` merged over them.
struct ThemeTypesetter: Sendable {
    // MARK: - Property
    private let fonts: FontFinder
    private let typesetter: Typesetter
    private let reader = LookReader()
    private let merger = LookMerger()

    // MARK: - Initializer
    init(
        shaper: any ShapingProvider,
        library: ReferenceLibrary
    ) {
        self.fonts = FontFinder(shaper: shaper, library: library)
        self.typesetter = Typesetter(shaper: shaper)
    }

    // MARK: - Public
    // `clip` is the place of the title's clip. A run without a style is in the clip's, and a run's style is named at
    // its index in the title's list. A style the theme does not hold stops where it is named. The default line height
    // follows the size of the clip's style with `character` merged over it.
    func layout(
        _ title: ClipTitle,
        clip: Place,
        width: Double?,
        theme: MergedTheme,
        scale: Double,
        kind: String
    ) throws -> TextLayout {
        let place = clip.appending(key: "title")
        try check(title.style, place: clip.appending(key: "style"), theme: theme, kind: kind)

        let character = LookStructureTable.character
        var faces: [String: [FontFace]] = [:]
        let textRuns = try title.runs.enumerated().map { index, run in
            let runStyle = run.style ?? title.style
            if let named = run.style {
                try check(named, place: place.appending(index: index).appending(key: "style"), theme: theme, kind: kind)
            }

            let written = theme.style(named: runStyle)
            let merged = try merged(title.character, over: written, as: character, key: "character", clip: clip)
            let style = theme.characterStyle(of: merged, named: runStyle, scale: scale)
            let runFaces = try faces[runStyle] ?? fonts.faces(for: style, place: theme.fontPlace(ofStyle: runStyle))
            faces[runStyle] = runFaces

            return TextRun(text: run.text, style: style, faces: runFaces)
        }

        let clipStyle = theme.style(named: title.style)
        let sized = try merged(title.character, over: clipStyle, as: character, key: "character", clip: clip)
        let paragraph = try merged(
            title.paragraph,
            over: clipStyle,
            as: LookStructureTable.paragraph,
            key: "paragraph",
            clip: clip
        )

        return try typesetter.layout(
            textRuns,
            paragraph: theme.paragraphStyle(of: paragraph, size: sized["size"]?.numberValue ?? 0, scale: scale),
            width: width,
            place: place,
            kind: kind
        )
    }

    // MARK: - Private
    // A title's static `character` or `paragraph` merged over a style, leaf by leaf. A leaf the merged value requires
    // and no layer gives stops.
    private func merged(
        _ property: LookProperty?,
        over style: JSONObject,
        as structure: ValueStructure,
        key: String,
        clip: Place
    ) throws -> JSONObject {
        guard let written = property?.written else { return style }
        let below = reader.value(of: .object(style), as: structure)
        let over = reader.value(of: written, as: structure)
        let place = clip.appending(key: key)
        let value = try merger.merge(below, over, as: structure, place: place)
        do {
            try merger.checkRequired(in: value, as: structure, place: place)
        } catch let LookError.missingLeaf(_, missing) {
            throw ResolveError.missingLookLeaf(place: place, kind: .clip(.title), key: missing, layer: nil)
        }

        return value.json(as: structure)?.objectValue ?? style
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
