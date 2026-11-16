//
//  MergedTheme+Value.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The values resolve reads from a merged theme, typed. The base theme holds every key below, and the key tables and
// reference checks let only these shapes through, so a value is always there. Lengths come back in points unless a
// length scale is given.
extension MergedTheme {
    // MARK: - Property
    var baseWidth: Double {
        number(at: ["baseWidth"])
    }

    var areaPadding: Double {
        number(at: ["area", "padding"])
    }

    var cropPadding: Double {
        number(at: ["area", "cropPadding"])
    }

    var placementPadding: Double {
        number(at: ["placement", "padding"])
    }

    var arrowWidth: Double {
        number(at: ["shapes", "arrow", "width"])
    }

    var arrowLength: Double {
        number(at: ["shapes", "arrow", "length"])
    }

    var arrowHead: Double {
        number(at: ["shapes", "arrow", "head"])
    }

    var boxWidth: Double {
        number(at: ["shapes", "box", "width"])
    }

    var boxRadius: Double {
        number(at: ["shapes", "box", "radius"])
    }

    var borderWidth: Double {
        number(at: ["shapes", "border", "width"])
    }

    var bannerPadding: Double {
        number(at: ["image", "bannerPadding"])
    }

    var layoutGap: Double {
        number(at: ["layout", "gap"])
    }

    var layoutPadding: Double {
        number(at: ["layout", "padding"])
    }

    var labelSides: [Side] {
        (value(at: ["shapes", "label", "sides"])?.arrayValue ?? []).compactMap { $0.stringValue.flatMap(Side.init) }
    }

    // Where the font list was written, which a stop on it names.
    var fontPlace: Place {
        place(of: Place(components: [.key("font")]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // The length scale of a place `width` wide: theme lengths are points at `baseWidth`.
    // The filter choice a clip that writes none takes.
    var defaultFilter: JSONValue {
        value(at: ["defaults", "filter"]) ?? .string("none")
    }

    func lengthScale(at width: Double) -> Double {
        width / baseWidth
    }

    // A colour is written as `#RRGGBB`, `#RRGGBBAA` or the name of a theme colour, which the reference checks found.
    func color(_ written: String) -> Color {
        guard !written.hasPrefix("#") else { return Color(written: written) }

        return Color(written: value(at: ["colors", written])?.stringValue ?? "#000000")
    }

    // A shape's theme colour, which a document's `color` replaces.
    func shapeColor(of shape: ShapeKind) -> Color {
        color(value(at: ["shapes", shape.rawValue, "color"])?.stringValue ?? "accent")
    }

    // Where a style places a title that gives no position, and how far it sits from the top or bottom edge, in points.
    func placement(ofStyle name: String) -> String? {
        value(at: ["styles", name, "placement"])?.stringValue
    }

    func offset(ofStyle name: String) -> Double? {
        value(at: ["styles", name, "offset"])?.numberValue
    }

    // A style with its lengths multiplied by `scale`. A property it leaves out takes the plain value: regular, the
    // `text` and `emphasis` colours, a line height of 1.25 times its size, left, no stroke, no background and no limit
    // on lines. A background leaves out the `background` colour, no padding and no radius, and a stroke the `text`
    // colour. Every style has a size, since the merged theme stopped on one without.
    func style(
        named name: String,
        scale: Double
    ) -> TextStyle {
        let style = value(at: ["styles", name])?.objectValue ?? JSONObject()
        let size = style["size"]?.numberValue ?? 0

        let font = Place(components: [.key("font")])
        return TextStyle(
            families: (value(at: ["font"])?.arrayValue ?? []).compactMap(\.stringValue),
            pack: pack(of: font),
            size: size * scale,
            weight: style["weight"]?.stringValue.flatMap(FontWeight.init) ?? .regular,
            color: color(style["color"]?.stringValue ?? "text"),
            emphasis: color(style["emphasis"]?.stringValue ?? "emphasis"),
            lineHeight: (style["lineHeight"]?.numberValue ?? size * 1.25) * scale,
            stroke: style["stroke"]?.objectValue.map { stroke in
                TextStroke(
                    width: (stroke["width"]?.numberValue ?? 0) * scale,
                    color: color(stroke["color"]?.stringValue ?? "text")
                )
            },
            background: style["background"]?.objectValue.map { background in
                let padding = background["padding"]?.arrayValue?.compactMap(\.numberValue) ?? [0, 0]
                return TextBackground(
                    color: color(background["color"]?.stringValue ?? "background"),
                    padding: Size(width: padding[1] * scale, height: padding[0] * scale),
                    radius: (background["radius"]?.numberValue ?? 0) * scale
                )
            },
            align: style["align"]?.stringValue.flatMap(TextAlignment.init) ?? .left,
            isOneLine: style["lines"]?.numberValue == 1
        )
    }

    // MARK: - Private
    private func value(at path: [String]) -> JSONValue? {
        path.reduce(Optional(value)) { value, key in value?.objectValue?[key] }
    }

    private func number(at path: [String]) -> Double {
        value(at: path)?.numberValue ?? 0
    }
}
