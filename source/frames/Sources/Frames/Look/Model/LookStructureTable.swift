//
//  LookStructureTable.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The structure of every value of a look, as the theme and the key tables give its keys. A keyframable key is made
// keyframable by declaring its structure here: its numbers and colours are its timed leaves, and the look merge and
// timing read nothing else of it.
enum LookStructureTable {
    static let fill = ValueStructure.forms([
        (ValueStructure.colorForm, .leaf(.color))
    ])

    static let stroke = ValueStructure.object(ObjectStructure(
        [
            ("color", .leaf(.color)),
            ("width", .leaf(.length(.positive))),
            ("join", .leaf(.name(among: StrokeJoin.allCases.map(\.rawValue)))),
            ("cap", .leaf(.name(among: StrokeCap.allCases.map(\.rawValue)))),
            ("start", .leaf(.name(among: StrokeEnd.allCases.map(\.rawValue)))),
            ("end", .leaf(.name(among: StrokeEnd.allCases.map(\.rawValue))))
        ],
        required: ["width"],
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
            ("color", .leaf(.color))
        ],
        shorthands: [.on, .color(key: "color")]
    ))

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

    static let textStyle = ValueStructure.object(ObjectStructure([
        ("font", .list(.leaf(.name))),
        ("size", .leaf(.length(.positive))),
        ("weight", .leaf(.name)),
        ("color", .leaf(.color)),
        ("lineHeight", .leaf(.length(.positive))),
        ("stroke", textStroke),
        ("background", background),
        ("placement", .leaf(.name)),
        ("offset", .leaf(.length())),
        ("align", .leaf(.name)),
        ("lines", .leaf(.number(.positive)))
    ]))

    static let shapeStyle = ValueStructure.object(ObjectStructure([
        ("fill", fill),
        ("stroke", stroke),
        ("radius", length),
        ("outset", length),
        ("shadow", shadow)
    ]))

    static let transition = ValueStructure.choice(offNames: ["cut"])

    static let filter = ValueStructure.choice(offNames: ["none"])

    // A filter as resolve gives it: its entries in order, each the ops of a preset or the one op written in place, and
    // the `mix` it is drawn with. A LUT's file is pinned, its SHA-256 beside it.
    static let resolvedFilter = ValueStructure.list(.object(ObjectStructure([
        ("ops", .list(.choice(offNames: [], forms: FilterKeyTable.operations.map { name in
            guard name == "lut", case let .object(lut) = filterOperation(name) else { return ("op:" + name, filterOperation(name)) }

            let keys = lut.keys.flatMap { key in key.name == "file" ? [key, ("sha256", .leaf(.name))] : [key] }
            return ("op:" + name, .object(ObjectStructure(keys)))
        }))),
        ("mix", mix)
    ])))

    static let mix = ValueStructure.leaf(.number(.range(0...1)))

    static let animation = ValueStructure.choice(offNames: ["none"])

    static let theme = ValueStructure.object(ObjectStructure([
        ("baseWidth", .leaf(.number(.positive))),
        ("font", .list(.leaf(.name))),
        ("colors", .map(.leaf(.color))),
        ("styles", .map(textStyle)),
        ("shapes", .map(shapeStyle)),
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

    // An op's parameters, in the order of the op table, each in its range, a length a theme length. A sampled length
    // at 0 leaves the picture as it is, so a length is 0 or more once it moves. An entry written in place also takes
    // `mix`.
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
        case "lut": [("file", .leaf(LeafKind(form: .file))), ("amount", .leaf(unit))]
        case "blur": [("radius", .leaf(length))]
        case "sharpen": [("amount", .leaf(.number())), ("radius", .leaf(length))]
        case "bloom": [("amount", .leaf(.number())), ("radius", .leaf(length)), ("color", .leaf(.color))]
        case "vignette": [("amount", .leaf(.number())), ("radius", .leaf(unit))]
        case "pixelate": [("size", .leaf(length))]
        default: [("amount", .leaf(unit)), ("size", .leaf(length))]
        }

        return mixed
            ? .object(ObjectStructure(parameters + [("mix", mix)], plain: ["mix": .number(1)]))
            : .object(ObjectStructure(parameters))
    }
}
