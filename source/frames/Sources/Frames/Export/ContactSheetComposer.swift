//
//  ContactSheetComposer.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Lays cells of one size out on a grid, left to right and then top down, each picture with its label centred on a band
// under it. The label is set in the base theme's `label` style whatever theme a document takes, so a form's theme never
// changes how a check looks. Lengths are the base theme's at the cell's width, as a title's are at its frame's width:
// `layout.gap` between cells, `layout.padding` around them, and the band is the label's height and one gap, all on the
// base theme's `background` colour. Gaps, padding and the band are whole pixels, so every picture starts on a pixel
// edge and is resampled once, from its source to its cell.
struct ContactSheetComposer: Sendable {
    // MARK: - Property
    private let theme = MergedTheme.base
    private let typesetter: ThemeTypesetter
    private let hasher: any FileHashProvider

    // MARK: - Initializer
    init(
        shaper: any ShapingProvider,
        library: ReferenceLibrary,
        hasher: any FileHashProvider
    ) {
        self.typesetter = ThemeTypesetter(shaper: shaper, library: library)
        self.hasher = hasher
    }

    // MARK: - Public
    // `size` is every cell's picture, in the sheet's pixels.
    func sheet(
        of cells: [ContactSheetCell],
        size: Size,
        columns: Int
    ) throws -> DisplayList {
        let scale = theme.lengthScale(at: size.width)
        let gap = (theme.layoutGap * scale).rounded()
        let padding = (theme.layoutPadding * scale).rounded()
        let labels = try cells.map { cell in
            try typesetter.layout(
                cell.label,
                style: "label",
                stylePlace: .root,
                width: nil,
                theme: theme,
                scale: scale,
                place: .root,
                kind: "label"
            )
        }
        let band = ((labels.map(\.size.height).max() ?? 0) + gap).rounded(.up)

        let columnCount = max(min(columns, cells.count), 1)
        let rowCount = (cells.count + columnCount - 1) / columnCount
        let items = try cells.indices.flatMap { index in
            let picture = Rectangle(
                x: padding + Double(index % columnCount) * (size.width + gap),
                y: padding + Double(index / columnCount) * (size.height + band + gap),
                width: size.width,
                height: size.height
            )

            let item = PictureItem(source: cells[index].picture, rectangle: nil, destination: picture)

            return [DisplayItem(content: .picture(item)), try labelItem(labels[index], under: picture, band: band)]
        }

        return DisplayList(
            size: Size(
                width: padding * 2 + length(of: columnCount, size.width, gap: gap),
                height: padding * 2 + length(of: rowCount, size.height + band, gap: gap)
            ),
            background: theme.color("background"),
            // The sheet draws no grain of its own.
            seed: 0,
            items: items
        )
    }

    // MARK: - Private
    private func labelItem(
        _ layout: TextLayout,
        under picture: Rectangle,
        band: Double
    ) throws -> DisplayItem {
        let frame = Rectangle(
            center: Point(x: picture.center.x, y: picture.maxY + band / 2),
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
