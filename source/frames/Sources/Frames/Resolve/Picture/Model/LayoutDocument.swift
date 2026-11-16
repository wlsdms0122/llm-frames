//
//  LayoutDocument.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A layout document as resolve reads it. `columns` is nil when every item goes on one row, and `border` is the colour
// cell borders are drawn in, nil for none.
struct LayoutDocument: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let theme: ThemeReference?
    let banner: [BannerLine]
    let columns: Int?
    let border: String?
    let items: [LayoutItem]

    // MARK: - Initializer
    init(
        place: Place,
        theme: ThemeReference?,
        banner: [BannerLine],
        columns: Int?,
        border: String?,
        items: [LayoutItem]
    ) {
        self.place = place
        self.theme = theme
        self.banner = banner
        self.columns = columns
        self.border = border
        self.items = items
    }

    // MARK: - Public
    // MARK: - Private
}
