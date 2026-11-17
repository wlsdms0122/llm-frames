//
//  BannerSetter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Sets a banner: its lines one under another, each in the style it names or `banner`, wrapped at the band's width less
// `image.bannerPadding` on each side and placed by its style's alignment, in a band as tall as its text with that
// padding above and below. A banner of no lines has no band.
struct BannerSetter: Sendable {
    // MARK: - Property
    private let text: ThemeTypesetter

    // MARK: - Initializer
    init(text: ThemeTypesetter) {
        self.text = text
    }

    // MARK: - Public
    // `top` is where the band starts on the canvas it is drawn on, and `scale` that canvas's length scale. The height
    // is in whole pixels, since it adds to the canvas.
    func banner(
        _ lines: [BannerLine],
        width: Double,
        top: Double,
        theme: MergedTheme,
        scale: Double,
        place: Place,
        kind: String
    ) throws -> (height: Double, text: [DrawingContent]) {
        guard !lines.isEmpty else { return (0, []) }

        let padding = theme.bannerPadding * scale
        var y = top + padding
        var contents: [DrawingContent] = []
        for (index, line) in lines.enumerated() {
            let linePlace = place.appending(index: index)
            let style = line.style ?? "banner"
            let layout = try text.layout(
                line.text,
                style: style,
                stylePlace: line.style == nil ? linePlace : linePlace.appending(key: "style"),
                width: width - padding * 2,
                theme: theme,
                scale: scale,
                place: linePlace,
                kind: kind
            )
            let frame = text.frame(
                of: layout,
                style: style,
                theme: theme,
                along: Rectangle(x: padding, y: y, width: width - padding * 2, height: layout.size.height)
            )
            contents.append(.text(layout, frame: frame))
            y += layout.size.height
        }

        return ((y + padding - top).rounded(.up), contents)
    }

    // MARK: - Private
}
