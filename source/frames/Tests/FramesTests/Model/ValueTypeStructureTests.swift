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
    private static let aligns = StrokeAlign.allCases.map(\.rawValue)
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
                    KeyRule("width", .number(.positive)),
                    KeyRule("align", .literal(Self.aligns)),
                    KeyRule("join", .literal(Self.joins)),
                    KeyRule("cap", .literal(Self.caps)),
                    KeyRule("start", .literal(Self.ends)),
                    KeyRule("end", .literal(Self.ends)),
                    KeyRule("dash", .dash(isKeyframed: false)),
                    KeyRule("dashOffset", .number(.any))
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
                KeyRule("radius", .number(.nonNegative)),
                KeyRule("outset", .number(.nonNegative)),
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
        #expect(border == Self.border)
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
                    rules: [KeyRule("color", .color), KeyRule("padding", .numbers(2, .nonNegative)), KeyRule("radius", .number(.nonNegative))]
                ))
            ])
        }
        #expect(rules == [
            .oneOf([
                .exactly(.bool(false)),
                .object(ObjectTable(kind: "stroke", rules: [KeyRule("width", .number(.positive)), KeyRule("color", .color)]))
            ]),
            box("background"),
            box("highlight"),
            .oneOf([
                .bool,
                .object(ObjectTable(
                    kind: "underline",
                    rules: [KeyRule("width", .number(.positive)), KeyRule("offset", .number(.any)), KeyRule("color", .color)]
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
                    KeyRule("threshold", .number(.any)),
                    KeyRule("ratio", .number(.any)),
                    KeyRule("knee", .number(.any)),
                    KeyRule("attack", .number(.any)),
                    KeyRule("release", .number(.any)),
                    KeyRule("makeup", .number(.any))
                ]
            ),
            ObjectTable(
                kind: "gate",
                rules: [
                    operation,
                    KeyRule("threshold", .number(.any)),
                    KeyRule("range", .number(.any)),
                    KeyRule("attack", .number(.any)),
                    KeyRule("hold", .number(.any)),
                    KeyRule("release", .number(.any))
                ]
            ),
            ObjectTable(
                kind: "limiter",
                rules: [
                    operation,
                    KeyRule("gain", .number(.any)),
                    KeyRule("ceiling", .number(.any)),
                    KeyRule("lookahead", .number(.any)),
                    KeyRule("release", .number(.any))
                ]
            ),
            ObjectTable(kind: "convolve", rules: [operation, KeyRule("file", .name), KeyRule("gain", .number(.any))])
        ])
        let type = KeyRule("type", .literal(AudioFilterKeyTable.bandTypes), isRequired: true)
        #expect(bands == MixBandType.allCases.map { band in
            ObjectTable(
                kind: "band",
                rules: [type, KeyRule("frequency", .number(.any))]
                    + (band.takesGain ? [KeyRule("gain", .number(.any))] : [])
                    + [KeyRule("q", .number(.any))]
            )
        })
    }

    @Test("a filter op's table requires only `op`, and leaves every parameter's range to the range check")
    func readsFilterOperations() {
        // When
        let tables = FilterKeyTable.operations.map(FilterKeyTable.table(for:))

        // Then
        let number = { (name: String) in KeyRule(name, .number(.any)) }
        let parameters: [String: [KeyRule]] = [
            "exposure": [number("ev")],
            "contrast": [number("amount")],
            "saturation": [number("amount")],
            "temperature": [number("kelvin")],
            "hue": [number("degrees")],
            "sepia": [number("amount")],
            "levels": [KeyRule("input", .numbers(2, .any)), KeyRule("output", .numbers(2, .any))],
            "lut": [KeyRule("file", .name), number("amount"), KeyRule("space", .literal(VocabularyTable.lookUpTableSpaces))],
            "blur": [number("radius")],
            "sharpen": [number("amount"), number("radius")],
            "bloom": [number("amount"), number("radius"), KeyRule("color", .color)],
            "vignette": [number("amount"), number("radius")],
            "displace": [KeyRule("file", .name), number("amount"), KeyRule("offset", .numbers(2, .any))],
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
            KeyRule("width", .number(.positive)),
            KeyRule("height", .number(.positive)),
            KeyRule("position", AreaKeyTable.point)
        ]
        let look = [
            KeyRule("feather", .number(.nonNegative)),
            KeyRule("invert", .bool),
            KeyRule("mode", .literal(MaskMode.allCases.map(\.rawValue)))
        ]
        let groups = ["width", "height", "position"].map { key in
            KeyGroup(keys: ["area", key], isExclusive: true, isOptional: true)
        }
        let radius = KeyRule("radius", .number(.nonNegative))
        #expect(ShapeKind.allCases == [.rect, .ellipse, .path])
        #expect(tables == [
            ObjectTable(kind: "rect mask", rules: [shape] + box + [radius] + look, groups: groups),
            ObjectTable(kind: "ellipse mask", rules: [shape] + box + look, groups: groups),
            ObjectTable(kind: "path mask", rules: [shape, KeyRule("points", .points(isKeyframed: false))] + look)
        ])
        #expect(MaskKeyTable.keyframe == ObjectTable(
            kind: "mask",
            rules: [shape] + box + [KeyRule("points", .points(isKeyframed: false)), radius] + look
        ))
    }

    @Test("a clip's border takes `true`, `false`, a colour or a border object, and its radius and outset are lengths 0 or more")
    func readsClipLooks() {
        // When
        let media = ClipKeyTable.table(for: .media(.video), in: .sequence)
        let rect = ClipKeyTable.table(for: .shape("rect"), in: .sequence)

        // Then
        #expect(media.rule(named: "border")?.type == .oneOf([.bool, .color, Self.border]))
        #expect(media.rule(named: "radius")?.type == .number(.nonNegative))
        #expect(rect.rule(named: "radius")?.type == .number(.nonNegative))
        #expect(rect.rule(named: "outset")?.type == .number(.nonNegative))
    }

    @Test("a theme's plain keys and a text style's are read from their structures, key by key")
    func readsThemeStyle() {
        // When
        let theme = ["baseWidth", "font", "placement"].map { ThemeKeyTable.theme.rule(named: $0)?.type }
        let style = ThemeKeyTable.style.rules.filter { !["stroke", "background", "highlight", "underline"].contains($0.name) }

        // Then
        #expect(theme == [
            .number(.positive),
            .list(.name),
            .object(ObjectTable(kind: "placement", rules: [KeyRule("padding", .number(.nonNegative))]))
        ])
        #expect(ThemeKeyTable.style.rules.map(\.name) == LookStructureTable.textStyle.keys.map(\.name))
        #expect(style == [
            KeyRule("font", .list(.name)),
            KeyRule("size", .number(.positive)),
            KeyRule("weight", .leaf(.fontWeight)),
            KeyRule("italic", .bool),
            KeyRule("tracking", .number(.any)),
            KeyRule("kerning", .literal(["metrics", "none"])),
            KeyRule("features", .leaf(.fontFeatures)),
            KeyRule("baselineShift", .number(.any)),
            KeyRule("color", .color),
            KeyRule("lineHeight", .number(.positive)),
            KeyRule("textOrientation", .literal(["mixed", "upright", "sideways"])),
            KeyRule("textCombineUpright", .literal(["none", "all"])),
            KeyRule("placement", .literal(VocabularyTable.placementNames)),
            KeyRule("offset", .number(.nonNegative)),
            KeyRule("writingMode", .literal(["horizontal-tb", "vertical-rl", "vertical-lr"])),
            KeyRule("direction", .literal(["auto", "ltr", "rtl"])),
            KeyRule("align", .literal(["left", "center", "right"])),
            KeyRule("lines", .leaf(.positiveInteger))
        ])
        #expect(ThemeKeyTable.character.rule(named: "size")?.type == .number(.positive))
        #expect(ThemeKeyTable.paragraph.rule(named: "align")?.type == .literal(["left", "center", "right"]))
    }

    @Test("a number leaf and each number of a list leaf take the leaf's domain, whatever its range")
    func readsLeafDomains() {
        // Given
        let structure = ValueStructure.object(ObjectStructure([
            ("ratio", .leaf(.number(.range(1...Double.infinity)))),
            ("frequency", .leaf(.number(.between(0, 24000)))),
            ("pair", .leaf(.numbers(count: 2, domain: .range(-1...1)))),
            ("any", .leaf(.numbers(count: 2)))
        ]))

        // When
        let sut = ValueType(structure: structure, kind: "test")

        // Then
        #expect(sut == .object(ObjectTable(
            kind: "test",
            rules: [
                KeyRule("ratio", .number(.range(1...Double.infinity))),
                KeyRule("frequency", .number(.between(0, 24000))),
                KeyRule("pair", .numbers(2, .range(-1...1))),
                KeyRule("any", .numbers(2, .any))
            ]
        )))
    }

    @Test(
        "the key check stops a number outside its leaf's domain, whatever its range, where it is written",
        arguments: [
            (#"{ "ratio": 0.5 }"#, "ratio (test): 0.5 is not 1 or more"),
            (#"{ "frequency": 24000 }"#, "frequency (test): 24000 is not above 0 and below 24000"),
            (#"{ "pair": [0, 1.5] }"#, "pair[1] (test): 1.5 is not within -1 to 1")
        ]
    )
    func checksLeafDomains(
        value: String,
        message: String
    ) throws {
        // Given
        let sut = KeyChecker()
        let json = try Fixture.json(value)
        let type = ValueType(structure: .object(ObjectStructure([
            ("ratio", .leaf(.number(.range(1...Double.infinity)))),
            ("frequency", .leaf(.number(.between(0, 24000)))),
            ("pair", .leaf(.numbers(count: 2, domain: .range(-1...1))))
        ])), kind: "test")

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(json, as: type, place: .root, kind: "test") }
        #expect(error?.description == message)
    }

    // MARK: - Private
    private static let gradient = ValueType.object(ObjectTable(
        kind: "gradient",
        rules: [
            KeyRule("linear", .object(ObjectTable(
                kind: "linear gradient",
                rules: [
                    KeyRule("from", .numbers(2, .any)),
                    KeyRule("to", .numbers(2, .any)),
                    KeyRule("stops", .stops(isKeyframed: false))
                ]
            ))),
            KeyRule("radial", .object(ObjectTable(
                kind: "radial gradient",
                rules: [
                    KeyRule("center", .numbers(2, .any)),
                    KeyRule("radius", .number(.positive)),
                    KeyRule("stops", .stops(isKeyframed: false))
                ]
            )))
        ],
        groups: [KeyGroup(keys: ["linear", "radial"], isExclusive: true)]
    ))

    private static let border = ValueType.object(ObjectTable(
        kind: "border",
        rules: [
            KeyRule("width", .number(.positive)),
            KeyRule("color", .color),
            KeyRule("align", .literal(aligns))
        ]
    ))
    private static let shadow = ValueType.object(ObjectTable(
        kind: "shadow",
        rules: [KeyRule("radius", .number(.nonNegative)), KeyRule("offset", .numbers(2, .any)), KeyRule("color", .color)]
    ))
}
