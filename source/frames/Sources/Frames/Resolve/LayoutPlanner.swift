//
//  LayoutPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans a layout document: its items on a grid, every column as wide as its widest item and every row as tall as its
// tallest, each item centred in its cell, with the heading above its cell in the `heading` style, the banner above
// the grid and a border around every cell. `layout.padding` lies around the grid and `layout.gap` between cells, and
// theme lengths scale by the widest item. The canvas is filled with the theme `background` first.
struct LayoutPlanner: Sendable {
    // MARK: - Property
    private let text: ThemeTypesetter
    private let banners: BannerSetter

    // MARK: - Initializer
    init(text: ThemeTypesetter) {
        self.text = text
        self.banners = BannerSetter(text: text)
    }

    // MARK: - Public
    // `items` are what the items draw, each with its size, in order.
    func plan(
        _ document: LayoutDocument,
        theme: MergedTheme,
        items: [(picture: DrawnPicture, size: Size)]
    ) throws -> PicturePlan {
        guard !items.isEmpty else {
            throw ResolveError.emptyLayout(place: document.place.appending(key: "items"), kind: .layout)
        }

        let written = document.columns ?? items.count
        guard written > 0 else {
            throw ResolveError.nonPositiveColumns(
                place: document.place.appending(key: "columns"),
                kind: .layout,
                columns: written
            )
        }

        let columns = min(written, items.count)
        let rows = stride(from: 0, to: items.count, by: columns).map { $0..<min($0 + columns, items.count) }
        let scale = theme.lengthScale(at: items.map(\.size.width).max() ?? 0)
        let gap = theme.layoutGap * scale
        let padding = theme.layoutPadding * scale
        let widths = (0..<columns).map { column in
            stride(from: column, to: items.count, by: columns).map { items[$0].size.width }.max() ?? 0
        }
        let heights = rows.map { row in row.map { items[$0].size.height }.max() ?? 0 }
        let headings = try document.items.indices.map { index in
            try document.items[index].heading.map { heading in
                try text.layout(
                    heading,
                    style: "heading",
                    width: widths[index % columns],
                    theme: theme,
                    scale: scale,
                    place: document.items[index].place.appending(key: "heading"),
                    kind: PlaceKind.layoutItem.label
                )
            }
        }
        let headingHeights = rows.map { row in row.compactMap { headings[$0]?.size.height }.max() ?? 0 }
        let width = (padding * 2 + widths.reduce(0, +) + gap * Double(columns - 1)).rounded(.up)
        let banner = try banners.banner(
            document.banner,
            width: width,
            top: 0,
            theme: theme,
            scale: scale,
            place: document.place.appending(key: "banner"),
            kind: PlaceKind.layout.label
        )
        let gridHeight = zip(heights, headingHeights).map(+).reduce(0, +) + gap * Double(rows.count - 1)
        let bounds = Rectangle(x: 0, y: 0, width: width, height: (banner.height + padding * 2 + gridHeight).rounded(.up))
        var contents: [DrawingContent] = [.fill(bounds, color: theme.color("background"))] + banner.text
        var top = banner.height + padding
        for (rowIndex, row) in rows.enumerated() {
            for index in row {
                let column = index % columns
                let left = padding + widths[..<column].reduce(0, +) + gap * Double(column)
                let cell = Rectangle(
                    x: left,
                    y: top + headingHeights[rowIndex],
                    width: widths[column],
                    height: heights[rowIndex]
                )
                if let heading = headings[index] {
                    let line = Rectangle(x: left, y: top, width: widths[column], height: heading.size.height)
                    contents.append(.text(heading, frame: text.frame(
                        of: heading,
                        style: "heading",
                        theme: theme,
                        along: line
                    )))
                }
                let size = items[index].size
                let frame = Rectangle(
                    x: cell.center.x - size.width / 2,
                    y: cell.center.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                contents.append(.picture(
                    items[index].picture,
                    crop: Rectangle(x: 0, y: 0, width: size.width, height: size.height),
                    frame: frame
                ))
                if let border = document.border {
                    // The border lies around the cell, so it covers none of the item.
                    let lineWidth = theme.borderWidth * scale
                    contents.append(.border(cell.grown(by: lineWidth), width: lineWidth, color: theme.color(border)))
                }
            }
            top += headingHeights[rowIndex] + heights[rowIndex] + gap
        }

        return PicturePlan(
            size: Size(width: bounds.width, height: bounds.height),
            steps: contents.map { DrawingStep(content: $0, clip: bounds) }
        )
    }

    // MARK: - Private
}
