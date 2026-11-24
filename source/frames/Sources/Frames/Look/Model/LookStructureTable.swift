//
//  LookStructureTable.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The structure of every value of a look. A keyframable key is made keyframable by declaring its structure here: its
// numbers and colours are its timed leaves, and the look merge and timing read nothing else of it. The key tables read
// the keys and domains of the look objects they check from here.
enum LookStructureTable {
    // A gradient's kind is its form and its number of stops the length of `stops`, both static; its points are
    // fractions of the shape's box, not theme lengths.
    static let gradientForms: [(name: String, structure: ValueStructure)] = [
        ("linear", .object(ObjectStructure(
            [("from", .leaf(.numbers(count: 2))), ("to", .leaf(.numbers(count: 2))), ("stops", stops)],
            required: ["from", "to", "stops"]
        ))),
        ("radial", .object(ObjectStructure(
            [("center", .leaf(.numbers(count: 2))), ("radius", .leaf(.number(.positive))), ("stops", stops)],
            required: ["center", "stops"],
            plain: ["radius": .number(1)]
        )))
    ]

    static let stops = ValueStructure.list(.tuple([.leaf(.number(.range(0...1))), .leaf(.color)]))

    static let solid = ValueStructure.leaf(.color)

    static let fill = ValueStructure.forms([(ValueStructure.colorForm, .leaf(.color))] + gradientForms)

    static let stroke = ValueStructure.object(ObjectStructure(
        [
            ("color", .leaf(.color)),
            ("gradient", .forms(gradientForms)),
            ("width", .leaf(.length(.positive))),
            ("align", .leaf(.name(among: StrokeAlign.allCases.map(\.rawValue)))),
            ("join", .leaf(.name(among: StrokeJoin.allCases.map(\.rawValue)))),
            ("cap", .leaf(.name(among: StrokeCap.allCases.map(\.rawValue)))),
            ("start", .leaf(.name(among: StrokeEnd.allCases.map(\.rawValue)))),
            ("end", .leaf(.name(among: StrokeEnd.allCases.map(\.rawValue)))),
            ("dash", .list(.leaf(.length()))),
            ("dashOffset", .leaf(.length(.any)))
        ],
        required: ["width"],
        nonZero: ["dash"],
        exclusive: [["color", "gradient"]]
    ))

    static let shadow = ValueStructure.object(ObjectStructure(
        [
            ("radius", .leaf(.length())),
            ("offset", .leaf(.lengths(count: 2))),
            ("color", .leaf(.color))
        ],
        shorthands: [.on]
    ))

    static let border = ValueStructure.object(ObjectStructure(
        [
            ("width", .leaf(.length(.positive))),
            ("color", .leaf(.color)),
            ("align", .leaf(.name(among: StrokeAlign.allCases.map(\.rawValue))))
        ],
        shorthands: [.on, .color(key: "color")]
    ))

    // A box's `radius` and a shape's `outset`: a corner cannot curve inwards, and an outset grows the outline a shape
    // draws around its geometry, where a smaller outline is a smaller geometry.
    static let length = ValueStructure.leaf(.length())

    static let textStroke = ValueStructure.object(ObjectStructure(
        [
            ("width", .leaf(.length(.positive))),
            ("color", .leaf(.color))
        ],
        required: ["width"]
    ))

    static let background = ValueStructure.object(ObjectStructure([
        ("color", .leaf(.color)),
        ("padding", .leaf(.lengths(count: 2, domain: .nonNegative))),
        ("radius", .leaf(.length()))
    ]))

    static let highlight = background

    static let underline = ValueStructure.object(ObjectStructure(
        [
            ("width", .leaf(.length(.positive))),
            ("offset", .leaf(.length(.any))),
            ("color", .leaf(.color))
        ],
        shorthands: [.on]
    ))

    // A text style's `kerning`, `textOrientation`, `textCombineUpright`, `writingMode`, `direction` and `align`, which
    // a title's `character` and `paragraph` write as well.
    static let kerning = ValueStructure.leaf(.name(among: ["metrics", "none"]))
    static let textOrientation = ValueStructure.leaf(.name(among: TextOrientation.allCases.map(\.rawValue)))
    static let textCombineUpright = ValueStructure.leaf(.name(among: TextCombineUpright.allCases.map(\.rawValue)))
    static let writingMode = ValueStructure.leaf(.name(among: WritingMode.allCases.map(\.rawValue)))
    static let direction = ValueStructure.leaf(.name(among: ["auto"] + TextDirection.allCases.map(\.rawValue)))
    static let align = ValueStructure.leaf(.name(among: TextAlignment.allCases.map(\.rawValue)))

    static let textStyle = ObjectStructure(
        [
            ("font", .list(.leaf(.name))),
            ("size", .leaf(.length(.positive))),
            ("weight", .leaf(.name)),
            ("italic", .leaf(.boolean)),
            ("tracking", .leaf(.number())),
            ("kerning", kerning),
            ("features", .map(.leaf(.staticNumber))),
            ("baselineShift", .leaf(.length(.any))),
            ("color", .leaf(.color)),
            ("lineHeight", .leaf(.length(.positive))),
            ("stroke", textStroke),
            ("background", background),
            ("highlight", highlight),
            ("underline", underline),
            ("textOrientation", textOrientation),
            ("textCombineUpright", textCombineUpright),
            ("placement", .leaf(.name(among: VocabularyTable.placementNames))),
            ("offset", .leaf(.length())),
            ("writingMode", writingMode),
            ("direction", direction),
            ("align", align),
            ("lines", .leaf(.number(.positive)))
        ],
        checks: ["weight": .fontWeight, "features": .fontFeatures, "lines": .positiveInteger]
    )

    // A title's character attributes: those that decide faces, shaping and line breaks are static.
    static let character = ValueStructure.object(ObjectStructure(
        [
            ("font", .list(.leaf(.name))),
            ("size", .leaf(LeafKind(form: .staticNumber, domain: .positive, isLength: true))),
            ("weight", .leaf(.name)),
            ("italic", .leaf(.boolean)),
            ("tracking", .leaf(.number())),
            ("kerning", kerning),
            ("features", .map(.leaf(.staticNumber))),
            ("baselineShift", .leaf(.length(.any))),
            ("color", .leaf(.color)),
            ("stroke", textStroke),
            ("highlight", highlight),
            ("underline", underline),
            ("textOrientation", textOrientation),
            ("textCombineUpright", textCombineUpright)
        ],
        checks: ["weight": .fontWeight, "features": .fontFeatures]
    ))

    // A title's paragraph attributes: `writingMode`, `direction` and `align` are static.
    static let paragraph = ValueStructure.object(ObjectStructure([
        ("writingMode", writingMode),
        ("direction", direction),
        ("align", align),
        ("lineHeight", .leaf(.length(.positive))),
        ("background", background)
    ]))

    static let shapeStyle = ObjectStructure([
        ("fill", fill),
        ("stroke", stroke),
        ("radius", length),
        ("outset", length),
        ("shadow", shadow)
    ])

    static let transition = ValueStructure.choice(offNames: ["cut"])

    static let filter = ValueStructure.choice(offNames: ["none"])

    // A filter as resolve gives it: its entries in order, each the ops of a preset or the one op written in place, and
    // the `mix` it is drawn with. A LUT's and a displacement map's file is pinned, its SHA-256 beside it.
    static let resolvedFilter = ValueStructure.list(.object(ObjectStructure([
        ("ops", .list(.choice(offNames: [], forms: FilterKeyTable.operations.map { name in
            guard case let .object(operation) = filterOperation(name), operation.keys.contains(where: { $0.name == "file" })
            else {
                return ("op:" + name, filterOperation(name))
            }

            let keys = operation.keys.flatMap { key in key.name == "file" ? [key, ("sha256", .leaf(.name))] : [key] }
            return ("op:" + name, .object(ObjectStructure(keys)))
        }))),
        ("mix", mix)
    ])))

    static let mix = ValueStructure.leaf(.number(.range(0...1)))

    static let animation = ValueStructure.choice(offNames: ["none"])

    // A path's vertex (FRAMES-11 Paths): its point and each of its tangents move as one leaf, and a vertex written as a
    // point names its point alone, its tangents `[0, 0]` where nothing writes them.
    static let pathVertex = ValueStructure.object(ObjectStructure(
        [
            ("vertex", .leaf(.numbers(count: 2))),
            ("inTangent", .leaf(.numbers(count: 2))),
            ("outTangent", .leaf(.numbers(count: 2)))
        ],
        required: ["vertex"],
        shorthands: [.point(key: "vertex")],
        plain: ["inTangent": .array([.number(0), .number(0)]), "outTangent": .array([.number(0), .number(0)])]
    ))

    // A clip's masks in order. Each mask's geometry is one form, `area`, the box `width`, `height` and `position`, or
    // `points`, which a keyframe may not change; an area and a position move as one leaf, and a path's vertices as
    // `pathVertex` says. Its `shape`, `invert` and `mode` are static.
    static let mask = ValueStructure.list(.object(ObjectStructure(
        [
            ("shape", .leaf(.name(among: VocabularyTable.shapes))),
            ("area", .leaf(.numbers(count: 4))),
            ("width", .leaf(.number(.positive))),
            ("height", .leaf(.number(.positive))),
            ("position", .leaf(.numbers(count: 2))),
            ("points", .list(pathVertex)),
            ("radius", .leaf(.number(.nonNegative))),
            ("feather", .leaf(.length())),
            ("invert", .leaf(.boolean)),
            ("mode", .leaf(.name(among: MaskMode.allCases.map(\.rawValue))))
        ],
        required: ["shape"],
        exclusive: [
            ["area", "width"], ["area", "height"], ["area", "position"], ["area", "points"],
            ["points", "width"], ["points", "height"], ["points", "position"]
        ],
        plain: ["radius": .number(0), "feather": .number(0), "invert": .bool(false), "mode": .string("add")]
    )))

    static let theme = ValueStructure.object(ObjectStructure([
        ("baseWidth", .leaf(.number(.positive))),
        ("font", .list(.leaf(.name))),
        ("colors", .map(.leaf(.color))),
        ("styles", .map(.object(textStyle))),
        ("shapes", .map(.object(shapeStyle))),
        ("placement", .object(ObjectStructure([("padding", length)]))),
        ("border", border),
        ("shadow", shadow),
        ("defaults", .object(ObjectStructure([
            ("transition", transition),
            ("filter", filter),
            ("animation", .object(ObjectStructure([
                ("title", .map(animation)),
                ("shape", animation),
                ("media", animation),
                ("adjust", animation)
            ])))
        ])))
    ]))

    // A filter choice whose presets are known, so its preset arguments, op parameters and entries' `mix` are timed. A
    // preset entry's arguments are typed by its parameters, each taking its default where no layer writes it.
    static func filter(presets: [(name: String, parameters: [Parameter])]) -> ValueStructure {
        let presetForms = presets.map { preset in
            let arguments = preset.parameters.compactMap { parameter -> (name: String, structure: ValueStructure)? in
                switch parameter.type {
                case .number:
                    (parameter.name, .leaf(.number()))

                case .color:
                    (parameter.name, .leaf(.color))

                case .video, .sequence, .image, .audio, .text, .choice:
                    nil
                }
            }
            let defaults = preset.parameters.reduce(into: [String: JSONValue]()) { defaults, parameter in
                defaults[parameter.name] = parameter.defaultValue
            }
            let body = ObjectStructure(
                [("args", .object(ObjectStructure(arguments, plain: defaults))), ("mix", mix)],
                plain: ["args": .object(JSONObject()), "mix": .number(1)]
            )
            return ("preset:" + preset.name, ValueStructure.object(body))
        }
        let operationForms = FilterKeyTable.operations.map { name in
            ("op:" + name, filterOperation(name, mixed: true))
        }

        return .choice(offNames: ["none"], forms: presetForms + operationForms)
    }

    // An op's parameters, in the order of the op table, a length a theme length, each required but a bloom's `color`,
    // a LUT's `space`, which is `srgb` where none is written, and a displace's `offset`, `[0, 0]` where none is
    // written. Each leaf's domain is its parameter's range: `PresetReader.checkRanges` stops on a value outside it and
    // a sample is clamped to it. A length is above 0 where it holds and 0 or more once it moves, since a sampled length
    // at 0 leaves the picture as it is. An `offset` takes any real number. An entry written in place also takes `mix`.
    static func filterOperation(
        _ name: String,
        mixed: Bool = false
    ) -> ValueStructure {
        let unit = LeafKind.number(.range(0...1))
        let length = LeafKind.length(.positive)
        let levels = LeafKind.numbers(count: 2, domain: .range(0...1))
        let parameters: [(name: String, structure: ValueStructure)] = switch name {
        case "exposure": [("ev", .leaf(.number()))]
        case "contrast", "saturation": [("amount", .leaf(.number()))]
        case "temperature": [("kelvin", .leaf(.number()))]
        case "hue": [("degrees", .leaf(.number()))]
        case "sepia": [("amount", .leaf(unit))]
        case "levels": [("input", .leaf(levels)), ("output", .leaf(levels))]
        case "lut":
            [
                ("file", .leaf(LeafKind(form: .file))),
                ("amount", .leaf(unit)),
                ("space", .leaf(.name(among: VocabularyTable.lookUpTableSpaces)))
            ]
        case "blur": [("radius", .leaf(length))]
        case "sharpen": [("amount", .leaf(.number())), ("radius", .leaf(length))]
        case "bloom": [("amount", .leaf(.number())), ("radius", .leaf(length)), ("color", .leaf(.color))]
        case "vignette": [("amount", .leaf(.number())), ("radius", .leaf(unit))]
        case "displace":
            [
                ("file", .leaf(LeafKind(form: .file))),
                ("amount", .leaf(length)),
                ("offset", .leaf(.lengths(count: 2)))
            ]
        case "pixelate": [("size", .leaf(length))]
        default: [("amount", .leaf(unit)), ("size", .leaf(length))]
        }

        let required = parameters.map(\.name).filter { $0 != "color" && $0 != "space" && $0 != "offset" }
        let plain: [String: JSONValue] = switch name {
        case "lut": ["space": .string(ColorSpace.srgb.rawValue)]
        case "displace": ["offset": .array([.number(0), .number(0)])]
        default: [:]
        }

        return mixed
            ? .object(ObjectStructure(
                parameters + [("mix", mix)],
                required: required,
                plain: plain.merging(["mix": .number(1)]) { first, _ in first }
            ))
            : .object(ObjectStructure(parameters, required: required, plain: plain))
    }

    // An audio filter choice whose presets are known, each entry with its `mix`. A preset entry's arguments are
    // numbers, each taking its default where no layer writes it. Its structure is static, so its presets, its ops, the
    // number and types of its bands and a limiter's `lookahead` are as the clip or the sequence writes them, and an
    // argument named in a preset's `staticArguments`, one a static parameter such as a `lookahead` reads, is static too.
    static func audioFilter(
        presets: [(name: String, parameters: [Parameter], staticArguments: Set<String>)]
    ) -> ValueStructure {
        let presetForms = presets.map { preset in
            let arguments = preset.parameters.map { parameter in
                let kind = preset.staticArguments.contains(parameter.name) ? LeafKind.staticNumber : .number()
                return (name: parameter.name, structure: ValueStructure.leaf(kind))
            }
            let defaults = preset.parameters.reduce(into: [String: JSONValue]()) { defaults, parameter in
                defaults[parameter.name] = parameter.defaultValue
            }
            let body = ObjectStructure(
                [("args", .object(ObjectStructure(arguments, plain: defaults))), ("mix", mix)],
                plain: ["args": .object(JSONObject()), "mix": .number(1)]
            )
            return ("preset:" + preset.name, ValueStructure.object(body))
        }
        let operationForms = AudioFilterKeyTable.operations.map { name in
            ("op:" + name, audioOperation(name, mixed: true))
        }

        return .choice(offNames: [], forms: presetForms + operationForms)
    }

    // An audio filter as resolve gives it: its entries in order, each its ops and the `mix` it is heard with. An
    // impulse response's file is pinned, its SHA-256 beside it.
    static let resolvedAudioFilter = ValueStructure.list(.object(ObjectStructure([
        ("ops", .list(.choice(offNames: [], forms: AudioFilterKeyTable.operations.map { name in
            guard
                case let .object(operation) = audioOperation(name),
                operation.keys.contains(where: { $0.name == "file" })
            else {
                return ("op:" + name, audioOperation(name))
            }

            let keys = operation.keys.flatMap { key in key.name == "file" ? [key, ("sha256", .leaf(.name))] : [key] }
            return ("op:" + name, .object(ObjectStructure(keys)))
        }))),
        ("mix", mix)
    ])))

    // An audio op's parameters in the order of the op table, each in its range with its default written, and those
    // with no default required. A band's `frequency` and `q` are heard by their ratio, so they move geometrically. A
    // limiter's `lookahead` sets the one window its hold and its ramp share, so it is static, and a `convolve`'s `file`
    // is a file, static too.
    static func audioOperation(
        _ name: String,
        mixed: Bool = false
    ) -> ValueStructure {
        let seconds = LeafKind.number(.positive)
        let (parameters, defaults): ([(name: String, structure: ValueStructure)], [String: JSONValue]) = switch name {
        case "eq":
            ([("bands", .list(band))], [:])

        case "compressor":
            (
                [
                    ("threshold", .leaf(.number())),
                    ("ratio", .leaf(.number(.range(1...Double.infinity)))),
                    ("knee", .leaf(.number(.nonNegative))),
                    ("attack", .leaf(seconds)),
                    ("release", .leaf(seconds)),
                    ("makeup", .leaf(.number()))
                ],
                ["knee": .number(0), "attack": .number(0.01), "release": .number(0.1), "makeup": .number(0)]
            )

        case "limiter":
            (
                [
                    ("gain", .leaf(.number())),
                    ("ceiling", .leaf(.number(.range(-Double.infinity...0)))),
                    ("lookahead", .leaf(LeafKind(form: .staticNumber, domain: .range(0.0015...0.05)))),
                    ("release", .leaf(seconds))
                ],
                ["gain": .number(0), "ceiling": .number(-1), "lookahead": .number(0.005), "release": .number(0.1)]
            )

        case "convolve":
            ([("file", .leaf(LeafKind(form: .file))), ("gain", .leaf(.number()))], ["gain": .number(0)])

        default:
            (
                [
                    ("threshold", .leaf(.number())),
                    ("range", .leaf(.number(.range(-Double.infinity...0)))),
                    ("attack", .leaf(seconds)),
                    ("hold", .leaf(.number(.nonNegative))),
                    ("release", .leaf(seconds))
                ],
                ["range": .number(-80), "attack": .number(0.001), "hold": .number(0.05), "release": .number(0.1)]
            )
        }

        let required = name == "eq" ? [] : parameters.map(\.name).filter { defaults[$0] == nil }

        return mixed
            ? .object(ObjectStructure(
                parameters + [("mix", mix)],
                required: required,
                plain: defaults.merging(["mix": .number(1)]) { $1 }
            ))
            : .object(ObjectStructure(parameters, required: required, plain: defaults))
    }

    // A band is a form by its `type`, each requiring the keys its type takes but `q`, which defaults to 1/√2. A band's
    // `frequency` lies above 0 and below half of 48 kHz.
    static let band = ValueStructure.choice(offNames: [], forms: MixBandType.allCases.map { type in
        let keys: [(name: String, structure: ValueStructure)] = [
            ("frequency", .leaf(LeafKind(form: .number, domain: .between(0, 24000), interpolation: .geometric))),
            ("gain", .leaf(.number())),
            ("q", .leaf(.ratio))
        ]
        let taken = keys.filter { $0.name != "gain" || type.takesGain }
        let body = ObjectStructure(
            taken,
            required: taken.map(\.name).filter { $0 != "q" },
            plain: ["q": .number(0.7071)]
        )
        return ("type:" + type.rawValue, .object(body))
    })
}
