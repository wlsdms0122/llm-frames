//
//  ThemeTypesetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Sets text in a named theme style, with the style's lengths multiplied by the length scale of the place the text is
// drawn, in the face its font list finds.
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
    func layout(
        _ text: String,
        style name: String,
        width: Double?,
        theme: MergedTheme,
        scale: Double,
        place: Place,
        kind: String
    ) throws -> TextLayout {
        let style = theme.style(named: name, scale: scale)
        let face = try fonts.face(for: style, place: theme.fontPlace)

        return try typesetter.layout(text, style: style, face: face, width: width, place: place, kind: kind)
    }

    // The box of set text along a line, placed by its style's alignment, its top on the line's.
    func frame(
        of layout: TextLayout,
        style name: String,
        theme: MergedTheme,
        along line: Rectangle
    ) -> Rectangle {
        let x = switch theme.style(named: name, scale: 1).align {
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
}
