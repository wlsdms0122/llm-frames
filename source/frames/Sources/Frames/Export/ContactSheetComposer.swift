//
//  ContactSheetComposer.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Lays frames of one size out on a grid, left to right and then top down, each with its time label burnt into its top
// left corner. The label is set in the face it is given, in one fixed tool style that no theme changes, at a size S
// that follows the longer side of the frame as drawn. Frames lie S apart with S around them, and S is a whole number of
// pixels, so every frame starts on a pixel edge and is resampled once, from its source to its cell.
struct ContactSheetComposer: Sendable {
    // MARK: - Property
    private static let textColor = Color(written: "#FFFFFFFF")
    private static let labelBackground = Color(written: "#000000B3")
    private static let sheetBackground = Color(written: "#202020FF")

    private let typesetter: Typesetter
    private let hasher: any FileHashProvider

    // MARK: - Initializer
    init(
        shaper: any ShapingProvider,
        hasher: any FileHashProvider
    ) {
        self.typesetter = Typesetter(shaper: shaper)
        self.hasher = hasher
    }

    // MARK: - Public
    // `size` is every frame as drawn, in the sheet's pixels, and `face` is the face the labels are set in.
    func sheet(
        of cells: [ContactSheetCell],
        size: Size,
        columns: Int,
        face: FontFace
    ) throws -> DisplayList {
        let labelSize = max(14, (max(size.width, size.height) / 40).rounded())
        let character = characterStyle(size: labelSize)
        let paragraph = paragraphStyle(size: labelSize, face: face)
        let columnCount = max(min(columns, cells.count), 1)
        let rowCount = (cells.count + columnCount - 1) / columnCount
        let items = try cells.indices.flatMap { index in
            let picture = Rectangle(
                x: labelSize + Double(index % columnCount) * (size.width + labelSize),
                y: labelSize + Double(index / columnCount) * (size.height + labelSize),
                width: size.width,
                height: size.height
            )
            let item = PictureItem(source: cells[index].picture, rectangle: nil, destination: picture)
            let layout = try typesetter.layout(
                [TextRun(text: cells[index].label, style: character, face: face)],
                paragraph: paragraph,
                width: nil,
                place: .root,
                kind: "time label"
            )

            return [DisplayItem(content: .picture(item)), try labelItem(layout, on: picture, inset: labelSize / 2)]
        }

        return DisplayList(
            size: Size(
                width: labelSize * 2 + length(of: columnCount, size.width, gap: labelSize),
                height: labelSize * 2 + length(of: rowCount, size.height, gap: labelSize)
            ),
            background: Self.sheetBackground,
            // The sheet draws no grain of its own.
            seed: 0,
            items: items
        )
    }

    // MARK: - Private
    // The face is given, so the style's families and weight are not read.
    private func characterStyle(size: Double) -> CharacterStyle {
        CharacterStyle(families: [], pack: nil, weight: .regular, size: size, color: Self.textColor, stroke: nil)
    }

    // The line box is the face's ascent and descent at the size, and the background lies around it.
    private func paragraphStyle(
        size: Double,
        face: FontFace
    ) -> ParagraphStyle {
        ParagraphStyle(
            lineHeight: (face.ascent + face.descent) * size,
            background: TextBackground(
                color: Self.labelBackground,
                padding: Size(width: size / 2, height: size / 4),
                radius: size * 0.3
            ),
            align: .left,
            lines: 1
        )
    }

    // The label's background, which fills its box, has its top left `inset` from the picture's.
    private func labelItem(
        _ layout: TextLayout,
        on picture: Rectangle,
        inset: Double
    ) throws -> DisplayItem {
        let frame = Rectangle(
            x: picture.x + inset,
            y: picture.y + inset,
            width: layout.size.width,
            height: layout.size.height
        )

        return DisplayItem(
            transform: AffineTransform(mapping: layout.size, onto: frame),
            content: .glyphs(GlyphsItem(text: try ResolvedText(layout: layout, hashes: hasher)))
        )
    }

    // `count` lengths with a gap between each two.
    private func length(
        of count: Int,
        _ length: Double,
        gap: Double
    ) -> Double {
        Double(count) * length + Double(max(count - 1, 0)) * gap
    }
}
