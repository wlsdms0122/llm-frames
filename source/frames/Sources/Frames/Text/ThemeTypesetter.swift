//
//  ThemeTypesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Lays a title's runs out in named theme styles, with each style's lengths multiplied by the length scale of the place
// the text is drawn: each run in its own style's character attributes and the face its font query finds, and the whole
// title in the paragraph attributes of the clip's style.
struct ThemeTypesetter: Sendable {
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
    // `style` is the clip's style and `stylePlace` where it is named. A run without a style is in the clip's, and a
    // run's style is named at its index in the list `place` names. A style the theme does not hold stops where it is
    // named.
    func layout(
        _ runs: [TitleRun],
        style name: String,
        stylePlace: Place,
        width: Double?,
        theme: MergedTheme,
        scale: Double,
        place: Place,
        kind: String
    ) throws -> TextLayout {
        try check(name, place: stylePlace, theme: theme, kind: kind)

        var faces: [String: FontFace] = [:]
        let textRuns = try runs.enumerated().map { index, run in
            let runStyle = run.style ?? name
            if let named = run.style {
                try check(named, place: place.appending(index: index).appending(key: "style"), theme: theme, kind: kind)
            }

            let style = theme.characterStyle(named: runStyle, scale: scale)
            let face = try faces[runStyle] ?? fonts.face(for: style, place: theme.fontPlace)
            faces[runStyle] = face

            return TextRun(text: run.text, style: style, face: face)
        }

        return try typesetter.layout(
            textRuns,
            paragraph: theme.paragraphStyle(named: name, scale: scale),
            width: width,
            place: place,
            kind: kind
        )
    }

    // The box of set text along a line, placed by its style's alignment, its top on the line's.
    func frame(
        of layout: TextLayout,
        style name: String,
        theme: MergedTheme,
        along line: Rectangle
    ) -> Rectangle {
        let x = switch theme.paragraphStyle(named: name, scale: 1).align {
        case .left:
            line.x

        case .center:
            line.center.x - layout.size.width / 2

        case .right:
            line.maxX - layout.size.width
        }

        return Rectangle(x: x, y: line.y, width: layout.size.width, height: layout.size.height)
    }

    // MARK: - Private
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
