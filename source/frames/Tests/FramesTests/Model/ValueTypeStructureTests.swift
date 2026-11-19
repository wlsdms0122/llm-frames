//
//  ValueTypeStructureTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// The key tables of the look objects are read from their look structures. Each expectation is the table the key check
// gives that value, key by key.
@Suite("Value type structure Tests")
struct ValueTypeStructureTests {
    // MARK: - Property
    private static let joins = StrokeJoin.allCases.map(\.rawValue)
    private static let caps = StrokeCap.allCases.map(\.rawValue)
    private static let ends = StrokeEnd.allCases.map(\.rawValue)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a gradient is an object of one form key, each form's kind its name before the value's")
    func readsGradient() {
        // When
        let sut = ValueType(structure: .forms(LookStructureTable.gradientForms), kind: "gradient")

        // Then
        #expect(sut == Self.gradient)
    }

    @Test("a shape's fill, stroke and shadow take `false`, and a shadow `true`, beside their values")
    func readsShapeLooks() {
        // When
        let fill = ValueType(written: LookStructureTable.fill, kind: "gradient")
        let stroke = ValueType(written: LookStructureTable.stroke, kind: "stroke")
        let shadow = ValueType(written: LookStructureTable.shadow, kind: "shadow")

        // Then
        #expect(fill == .oneOf([.exactly(.bool(false)), .color, Self.gradient]))
        #expect(stroke == .oneOf([
            .exactly(.bool(false)),
            .object(ObjectTable(
                kind: "stroke",
                rules: [
                    KeyRule("color", .color),
                    KeyRule("gradient", Self.gradient),
                    KeyRule("width", .positiveNumber),
                    KeyRule("join", .literal(Self.joins)),
                    KeyRule("cap", .literal(Self.caps)),
                    KeyRule("start", .literal(Self.ends)),
                    KeyRule("end", .literal(Self.ends)),
                    KeyRule("dash", .dash(isKeyframed: false)),
                    KeyRule("dashOffset", .number)
                ],
                groups: [KeyGroup(keys: ["color", "gradient"], isExclusive: true, isOptional: true)]
            ))
        ]))
        #expect(shadow == .oneOf([.bool, Self.shadow]))
        #expect(ShapeKeyTable.style == ObjectTable(
            kind: "shape style",
            rules: [
                KeyRule("fill", fill),
                KeyRule("stroke", stroke),
                KeyRule("radius", .nonNegativeNumber),
                KeyRule("outset", .nonNegativeNumber),
                KeyRule("shadow", shadow)
            ]
        ))
    }

    @Test("the theme's border and shadow are objects alone, each length in its domain")
    func readsThemeLooks() {
        // When
        let border = ThemeKeyTable.theme.rule(named: "border")?.type
        let shadow = ThemeKeyTable.theme.rule(named: "shadow")?.type

        // Then
        #expect(border == .object(ObjectTable(
            kind: "border",
            rules: [KeyRule("width", .positiveNumber), KeyRule("color", .color)]
        )))
        #expect(shadow == Self.shadow)
    }

    @Test("a text style's stroke, background and highlight take `false`, and its underline `true`, beside their values")
    func readsTextLooks() {
        // When
        let rules = ["stroke", "background", "highlight", "underline"].map { ThemeKeyTable.style.rule(named: $0)?.type }

        // Then
        let box = { (kind: String) in
            ValueType.oneOf([
                .exactly(.bool(false)),
                .object(ObjectTable(
                    kind: kind,
                    rules: [KeyRule("color", .color), KeyRule("padding", .numbers(2)), KeyRule("radius", .nonNegativeNumber)]
                ))
            ])
        }
        #expect(rules == [
            .oneOf([
                .exactly(.bool(false)),
                .object(ObjectTable(kind: "stroke", rules: [KeyRule("width", .positiveNumber), KeyRule("color", .color)]))
            ]),
            box("background"),
            box("highlight"),
            .oneOf([
                .bool,
                .object(ObjectTable(
                    kind: "underline",
                    rules: [KeyRule("width", .positiveNumber), KeyRule("offset", .number), KeyRule("color", .color)]
                ))
            ])
        ])
    }

    @Test("an audio op's table requires only `op` and a band's only `type`, and leaves every parameter's domain to the domain check")
    func readsAudioOperations() {
        // When
        let tables = AudioFilterKeyTable.operations.map(AudioFilterKeyTable.table(for:))
        let bands = AudioFilterKeyTable.bandTypes.map(AudioFilterKeyTable.band(of:))

        // Then
        let operation = KeyRule("op", .literal(AudioFilterKeyTable.operations), isRequired: true)
        #expect(tables == [
            ObjectTable(kind: "eq", rules: [operation, KeyRule("bands", .list(.anyObject))]),
            ObjectTable(
                kind: "compressor",
                rules: [
                    operation,
                    KeyRule("threshold", .number),
                    KeyRule("ratio", .number),
                    KeyRule("knee", .number),
                    KeyRule("attack", .number),
                    KeyRule("release", .number),
                    KeyRule("makeup", .number)
                ]
            ),
            ObjectTable(
                kind: "gate",
                rules: [
                    operation,
                    KeyRule("threshold", .number),
                    KeyRule("range", .number),
                    KeyRule("attack", .number),
                    KeyRule("hold", .number),
                    KeyRule("release", .number)
                ]
            )
        ])
        let type = KeyRule("type", .literal(AudioFilterKeyTable.bandTypes), isRequired: true)
        #expect(bands == MixBandType.allCases.map { band in
            ObjectTable(
                kind: "band",
                rules: [type, KeyRule("frequency", .number)]
                    + (band.takesGain ? [KeyRule("gain", .number)] : [])
                    + [KeyRule("q", .number)]
            )
        })
    }

    @Test("a filter op's table requires only `op`, and leaves every parameter's range to the range check")
    func readsFilterOperations() {
        // When
        let tables = FilterKeyTable.operations.map(FilterKeyTable.table(for:))

        // Then
        let number = { (name: String) in KeyRule(name, .number) }
        let parameters: [String: [KeyRule]] = [
            "exposure": [number("ev")],
            "contrast": [number("amount")],
            "saturation": [number("amount")],
            "temperature": [number("kelvin")],
            "hue": [number("degrees")],
            "sepia": [number("amount")],
            "levels": [KeyRule("input", .numbers(2)), KeyRule("output", .numbers(2))],
            "lut": [KeyRule("file", .name), number("amount")],
            "blur": [number("radius")],
            "sharpen": [number("amount"), number("radius")],
            "bloom": [number("amount"), number("radius"), KeyRule("color", .color)],
            "vignette": [number("amount"), number("radius")],
            "pixelate": [number("size")],
            "grain": [number("amount"), number("size")]
        ]
        let operation = KeyRule("op", .literal(FilterKeyTable.operations), isRequired: true)
        #expect(tables == FilterKeyTable.operations.map { name in
            ObjectTable(kind: name, rules: [operation] + (parameters[name] ?? []))
        })
    }

    @Test("a mask's table for each shape takes the keys of its shape, `area` exclusive with each key of the box")
    func readsMasks() {
        // When
        let tables = ShapeKind.allCases.map(MaskKeyTable.table(for:))

        // Then
        let shape = KeyRule("shape", .literal(VocabularyTable.shapes))
        let box = [
            KeyRule("area", .area),
            KeyRule("width", .positiveNumber),
            KeyRule("height", .positiveNumber),
            KeyRule("position", AreaKeyTable.point)
        ]
        let look = [
            KeyRule("feather", .nonNegativeNumber),
            KeyRule("invert", .bool),
            KeyRule("mode", .literal(MaskMode.allCases.map(\.rawValue)))
        ]
        let groups = ["width", "height", "position"].map { key in
            KeyGroup(keys: ["area", key], isExclusive: true, isOptional: true)
        }
        let radius = KeyRule("radius", .nonNegativeNumber)
        #expect(ShapeKind.allCases == [.rect, .ellipse, .path])
        #expect(tables == [
            ObjectTable(kind: "rect mask", rules: [shape] + box + [radius] + look, groups: groups),
            ObjectTable(kind: "ellipse mask", rules: [shape] + box + look, groups: groups),
            ObjectTable(kind: "path mask", rules: [shape, KeyRule("points", .points)] + look)
        ])
        #expect(MaskKeyTable.keyframe == ObjectTable(
            kind: "mask",
            rules: [shape] + box + [KeyRule("points", .points), radius] + look
        ))
    }

    @Test("a clip's border takes only the border's shorthands, and its radius and outset are lengths 0 or more")
    func readsClipLooks() {
        // When
        let media = ClipKeyTable.table(for: .media(.video), in: .sequence)
        let rect = ClipKeyTable.table(for: .shape("rect"), in: .sequence)

        // Then
        #expect(media.rule(named: "border")?.type == .oneOf([.exactly(.bool(true)), .color]))
        #expect(media.rule(named: "radius")?.type == .nonNegativeNumber)
        #expect(rect.rule(named: "radius")?.type == .nonNegativeNumber)
        #expect(rect.rule(named: "outset")?.type == .nonNegativeNumber)
    }

    @Test("a theme's plain keys and a text style's are read from their structures, key by key")
    func readsThemeStyle() {
        // When
        let theme = ["baseWidth", "font", "placement"].map { ThemeKeyTable.theme.rule(named: $0)?.type }
        let style = ThemeKeyTable.style.rules.filter { !["stroke", "background", "highlight", "underline"].contains($0.name) }

        // Then
        #expect(theme == [
            .positiveNumber,
            .list(.name),
            .object(ObjectTable(kind: "placement", rules: [KeyRule("padding", .nonNegativeNumber)]))
        ])
        #expect(ThemeKeyTable.style.rules.map(\.name) == LookStructureTable.textStyle.keys.map(\.name))
        #expect(style == [
            KeyRule("font", .list(.name)),
            KeyRule("size", .positiveNumber),
            KeyRule("weight", .fontWeight),
            KeyRule("italic", .bool),
            KeyRule("tracking", .number),
            KeyRule("kerning", .literal(["metrics", "none"])),
            KeyRule("features", .fontFeatures),
            KeyRule("baselineShift", .number),
            KeyRule("color", .color),
            KeyRule("lineHeight", .positiveNumber),
            KeyRule("placement", .literal(VocabularyTable.placementNames)),
            KeyRule("offset", .nonNegativeNumber),
            KeyRule("align", .literal(["left", "center", "right"])),
            KeyRule("lines", .positiveInteger)
        ])
        #expect(ThemeKeyTable.character.rule(named: "size")?.type == .positiveNumber)
        #expect(ThemeKeyTable.paragraph.rule(named: "align")?.type == .literal(["left", "center", "right"]))
    }

    // MARK: - Private
    private static let gradient = ValueType.object(ObjectTable(
        kind: "gradient",
        rules: [
            KeyRule("linear", .object(ObjectTable(
                kind: "linear gradient",
                rules: [
                    KeyRule("from", .numbers(2)),
                    KeyRule("to", .numbers(2)),
                    KeyRule("stops", .stops(isKeyframed: false))
                ]
            ))),
            KeyRule("radial", .object(ObjectTable(
                kind: "radial gradient",
                rules: [
                    KeyRule("center", .numbers(2)),
                    KeyRule("radius", .positiveNumber),
                    KeyRule("stops", .stops(isKeyframed: false))
                ]
            )))
        ],
        groups: [KeyGroup(keys: ["linear", "radial"], isExclusive: true)]
    ))

    private static let shadow = ValueType.object(ObjectTable(
        kind: "shadow",
        rules: [KeyRule("radius", .nonNegativeNumber), KeyRule("offset", .numbers(2)), KeyRule("color", .color)]
    ))
}
