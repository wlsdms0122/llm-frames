//
//  TimedValue+Held.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames
import FramesTestMedia

// Timed values that hold one value at every time, as resolve gives a value no keyframe moves at an instant of 0, in
// the order resolve writes their leaves, and the typed values a timed value draws at a time.
extension TimedValue: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    // MARK: - Property
    // MARK: - Initializer
    public init(integerLiteral value: Int) {
        self = .held(.number(Double(value)))
    }

    public init(floatLiteral value: Double) {
        self = .held(.number(value))
    }

    // MARK: - Public
    static func held(_ value: LeafValue) -> TimedValue {
        .track([Keyframe(at: 0, value: value)])
    }

    // A corner `radius` held at its four radii, as resolve gives one written in either form.
    static func corners(_ radii: CornerRadii) -> TimedValue {
        .held(.numbers(radii.values))
    }

    static func fill(_ color: Color?) -> TimedValue {
        color.map { .form(ValueStructure.colorForm, .held(.color($0))) } ?? .off
    }

    static func stroke(_ stroke: PathStroke?) -> TimedValue {
        guard let stroke else { return .off }

        let dash = stroke.dash.map { lengths in
            TimedMember(key: "dash", value: .list(lengths.map { .held(.number($0)) }))
        }

        let paint: TimedMember = switch stroke.paint {
        case let .color(color):
            TimedMember(key: "color", value: .held(.color(color)))

        case .gradient:
            TimedMember(key: "gradient", value: .off)
        }

        return .object([
            paint,
            TimedMember(key: "width", value: .held(.number(stroke.width))),
            TimedMember(key: "align", value: .fixed(.string(stroke.align.rawValue))),
            TimedMember(key: "join", value: .fixed(.string(stroke.join.rawValue))),
            TimedMember(key: "cap", value: .fixed(.string(stroke.cap.rawValue))),
            TimedMember(key: "start", value: end(stroke.start)),
            TimedMember(key: "end", value: end(stroke.end))
        ] + [dash].compactMap { $0 } + [TimedMember(key: "dashOffset", value: .held(.number(stroke.dashOffset)))])
    }

    // A stroke's end as resolve writes it: off for no head, and otherwise its head's static values and its timed
    // `scale`.
    static func end(_ end: StrokeEnd) -> TimedValue {
        guard let head = end.head else { return .off }

        return .object(head.members.map { TimedMember(key: $0.key, value: .fixed($0.value)) } + [
            TimedMember(key: "scale", value: .held(.number(end.scale)))
        ])
    }

    static func shadow(_ shadow: DropShadow?) -> TimedValue {
        guard let shadow else { return .off }

        return .object([
            TimedMember(key: "radius", value: .held(.number(shadow.radius))),
            TimedMember(key: "offset", value: .held(.numbers([shadow.offset.x, shadow.offset.y]))),
            TimedMember(key: "color", value: .held(.color(shadow.color)))
        ])
    }

    static func border(_ border: MediaBorder?) -> TimedValue {
        guard let border else { return .off }

        return .object([
            TimedMember(key: "width", value: .held(.number(border.width))),
            TimedMember(key: "color", value: .held(.color(border.color))),
            TimedMember(key: "align", value: .fixed(.string(border.align.rawValue)))
        ])
    }

    // One entry of `operations` drawn with `mix`, none where there are no operations.
    static func filter(
        _ operations: [ResolvedFilterOperation],
        mix: Double = 1
    ) -> TimedValue {
        guard !operations.isEmpty else { return .off }

        return .list([.object([
            TimedMember(key: "ops", value: .list(operations.map(operation))),
            TimedMember(key: "mix", value: .held(.number(mix)))
        ])])
    }

    static func operation(_ operation: ResolvedFilterOperation) -> TimedValue {
        let number = { (key: String, value: Double) in TimedMember(key: key, value: .held(.number(value))) }
        let (name, members): (String, [TimedMember]) = switch operation {
        case let .exposure(ev): ("exposure", [number("ev", ev)])
        case let .contrast(amount): ("contrast", [number("amount", amount)])
        case let .saturation(amount): ("saturation", [number("amount", amount)])
        case let .temperature(kelvin): ("temperature", [number("kelvin", kelvin)])
        case let .hue(degrees): ("hue", [number("degrees", degrees)])
        case let .sepia(amount): ("sepia", [number("amount", amount)])
        case let .levels(input, output):
            (
                "levels",
                [
                    TimedMember(key: "input", value: .held(.numbers(input))),
                    TimedMember(key: "output", value: .held(.numbers(output)))
                ]
            )
        case let .lut(file, amount, space):
            (
                "lut",
                [
                    TimedMember(key: "file", value: .fixed(.string(file.path))),
                    TimedMember(key: "sha256", value: .fixed(.string(file.sha256))),
                    number("amount", amount),
                    TimedMember(key: "space", value: .fixed(.string(space.rawValue)))
                ]
            )
        case let .blur(radius): ("blur", [number("radius", radius)])
        case let .sharpen(amount, radius): ("sharpen", [number("amount", amount), number("radius", radius)])
        case let .bloom(amount, radius, color):
            ("bloom", [number("amount", amount), number("radius", radius)] + (color.map { color in
                [TimedMember(key: "color", value: .held(.color(color)))]
            } ?? []))
        case let .vignette(amount, radius): ("vignette", [number("amount", amount), number("radius", radius)])
        case let .displace(file, amount, offset):
            (
                "displace",
                [
                    TimedMember(key: "file", value: .fixed(.string(file.path))),
                    TimedMember(key: "sha256", value: .fixed(.string(file.sha256))),
                    number("amount", amount),
                    TimedMember(key: "offset", value: .held(.numbers([offset.x, offset.y])))
                ]
            )
        case let .pixelate(size): ("pixelate", [number("size", size)])
        case let .grain(amount, size): ("grain", [number("amount", amount), number("size", size)])
        }

        return .form("op:" + name, .object(members))
    }

    func fill(
        at time: Double = 0,
        box: Rectangle = Rectangle(x: 0, y: 0, width: 1, height: 1)
    ) -> Paint? {
        Paint(sampled: sampled(at: time, as: LookStructureTable.fill), box: box)
    }

    func stroke(
        at time: Double = 0,
        box: Rectangle = Rectangle(x: 0, y: 0, width: 1, height: 1)
    ) -> PathStroke? {
        PathStroke(sampled: sampled(at: time, as: LookStructureTable.stroke), factor: 1, carried: 1, box: box, isSample: false)
    }

    func shadow(at time: Double = 0) -> DropShadow? {
        DropShadow(sampled: sampled(at: time, as: LookStructureTable.shadow), factor: 1, carried: 1)
    }

    func border(at time: Double = 0) -> MediaBorder? {
        MediaBorder(sampled: sampled(at: time, as: LookStructureTable.border), factor: 1, isSample: false)
    }

    func filter(at time: Double = 0) -> [FilterEntry] {
        FilterEntry.entries(of: self, at: SampleTime(time))
    }

    func number(at time: Double = 0) -> Double? {
        sampled(at: time, as: LookStructureTable.length).number
    }

    func cornerRadii(at time: Double = 0) -> CornerRadii? {
        sampled(at: time, as: LookStructureTable.radius).cornerRadii
    }

    // MARK: - Private
}
