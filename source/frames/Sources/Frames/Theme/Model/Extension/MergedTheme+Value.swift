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

    var placementPadding: Double {
        number(at: ["placement", "padding"])
    }

    // The names of the styles the theme holds, in order, which a stop on a name it lacks lists.
    var styleNames: [String] {
        (value(at: ["styles"])?.objectValue?.keys ?? []).sorted()
    }

    // The names of the shape styles the theme holds, in order, which a stop on a name it lacks lists.
    var shapeStyleNames: [String] {
        (value(at: ["shapes"])?.objectValue?.keys ?? []).sorted()
    }

    // MARK: - Initializer
    // MARK: - Public
    // Where a style's font list was written, its own or the theme's, in the pack of the theme that wrote it.
    func fontList(ofStyle name: String) -> FontListOrigin {
        let path = fontPath(ofStyle: name)

        return FontListOrigin(place: place(of: path), kind: "theme", pack: pack(of: path))
    }

    // The length scale of a place `width` wide: theme lengths are points at `baseWidth`.
    func lengthScale(at width: Double) -> Double {
        width / baseWidth
    }

    // A colour is written as `#RRGGBB`, `#RRGGBBAA` or the name of a theme colour, which the reference checks found.
    func color(_ written: String) -> Color {
        guard !written.hasPrefix("#") else { return Color(written: written) }

        return Color(written: value(at: ["colors", written])?.stringValue ?? "#000000")
    }

    // Whether a colour written outside the theme, as in a preset, is a value or names a colour the theme holds.
    func isColor(_ written: String) -> Bool {
        written.hasPrefix("#") || value(at: ["colors", written]) != nil
    }

    // A colour a preset names, as a resolved document writes it. `place` is where the preset is chosen, and a name this
    // theme does not hold stops there.
    func presetColor(
        _ written: String,
        place: Place,
        kind: PlaceKind
    ) throws -> String {
        guard isColor(written) else { throw ResolveError.unknownPresetColor(place: place, kind: kind, name: written) }

        return color(written).hex
    }

    // A shape style as the theme holds it, its lengths in points, or nil for a name the theme does not hold.
    func shapeStyle(named name: String) -> JSONObject? {
        value(at: ["shapes", name])?.objectValue
    }

    // Where a style places a title that gives no position, and how far it sits from the top or bottom edge, in points.
    func placement(ofStyle name: String) -> String? {
        value(at: ["styles", name, "placement"])?.stringValue
    }

    func offset(ofStyle name: String) -> Double? {
        value(at: ["styles", name, "offset"])?.numberValue
    }

    // A style's character attributes with its size multiplied by `scale`. A property it leaves out takes the plain
    // value: the theme `font`, regular, upright, no tracking, kerned, and no highlight or underline. Every style has a
    // size, since the merged theme stopped on one without, and the typesetter stopped on a name the theme does not
    // hold.
    func characterStyle(
        named name: String,
        scale: Double
    ) -> CharacterStyle {
        characterStyle(of: style(named: name), scale: scale)
    }

    // `style` is a style with a title's `character` merged over it.
    func characterStyle(
        of style: JSONObject,
        scale: Double
    ) -> CharacterStyle {
        CharacterStyle(
            families: (style["font"] ?? value(at: ["font"]))?.arrayValue?.compactMap(\.stringValue) ?? [],
            weight: style["weight"].flatMap(FontWeight.init(written:)) ?? .regular,
            italic: style["italic"]?.boolValue ?? false,
            size: (style["size"]?.numberValue ?? 0) * scale,
            tracking: style["tracking"]?.numberValue ?? 0,
            isKerned: style["kerning"]?.stringValue != "none",
            features: (style["features"]?.objectValue?.members ?? []).compactMap { member in
                member.value.numberValue.map { FontFeature(tag: member.key, value: Int($0)) }
            },
            isHighlighted: style["highlight"]?.objectValue != nil,
            isUnderlined: style["underline"] == .bool(true) || style["underline"]?.objectValue != nil
        )
    }

    // A style's paragraph attributes with its lengths multiplied by `scale`. A property it leaves out takes the plain
    // value: a line height of 1.25 times its size, left, no background and no limit on lines. A background leaves out
    // the `background` colour, no padding and no radius.
    func paragraphStyle(
        named name: String,
        scale: Double
    ) -> ParagraphStyle {
        let style = style(named: name)

        return paragraphStyle(of: style, size: style["size"]?.numberValue ?? 0, scale: scale)
    }

    // `style` is a style with a title's `paragraph` merged over it, and `size` the size its default line height
    // follows, in points.
    func paragraphStyle(
        of style: JSONObject,
        size: Double,
        scale: Double
    ) -> ParagraphStyle {
        ParagraphStyle(
            lineHeight: (style["lineHeight"]?.numberValue ?? size * 1.25) * scale,
            background: style["background"]?.objectValue.map { box(of: $0, scale: scale) },
            align: style["align"]?.stringValue.flatMap(TextAlignment.init) ?? .left,
            lines: style["lines"]?.numberValue.map { Int($0) }
        )
    }

    // A style as the theme holds it, its lengths in points, empty for a name it does not hold.
    func style(named name: String) -> JSONObject {
        value(at: ["styles", name])?.objectValue ?? JSONObject()
    }

    // The value at a path of keys, as the theme holds it, its lengths in points.
    func value(at path: [String]) -> JSONValue? {
        path.reduce(Optional(value)) { value, key in value?.objectValue?[key] }
    }

    // MARK: - Private
    private func fontPath(ofStyle name: String) -> Place {
        let path = Place(components: [.key("styles"), .key(name), .key("font")])

        return style(named: name)["font"] == nil ? Place(components: [.key("font")]) : path
    }

    // A background: without `color` the `background` colour, without `padding` or `radius` 0.
    private func box(
        of written: JSONObject,
        scale: Double
    ) -> TextBackground {
        let padding = written["padding"]?.arrayValue?.compactMap(\.numberValue) ?? [0, 0]

        return TextBackground(
            color: color(written["color"]?.stringValue ?? "background"),
            padding: Size(width: padding[1] * scale, height: padding[0] * scale),
            radius: (written["radius"]?.numberValue ?? 0) * scale
        )
    }

    private func number(at path: [String]) -> Double {
        value(at: path)?.numberValue ?? 0
    }
}
