//
//  TimedValue+Held.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

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

    static func fill(_ color: Color?) -> TimedValue {
        color.map { .form(ValueStructure.colorForm, .held(.color($0))) } ?? .off
    }

    static func stroke(_ stroke: PathStroke?) -> TimedValue {
        guard let stroke else { return .off }

        return .object([
            TimedMember(key: "color", value: .held(.color(stroke.color))),
            TimedMember(key: "width", value: .held(.number(stroke.width))),
            TimedMember(key: "join", value: .fixed(.string(stroke.join.rawValue))),
            TimedMember(key: "cap", value: .fixed(.string(stroke.cap.rawValue))),
            TimedMember(key: "start", value: .fixed(.string(stroke.start.rawValue))),
            TimedMember(key: "end", value: .fixed(.string(stroke.end.rawValue)))
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
            TimedMember(key: "color", value: .held(.color(border.color)))
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
        case let .lut(file, amount):
            (
                "lut",
                [
                    TimedMember(key: "file", value: .fixed(.string(file.path))),
                    TimedMember(key: "sha256", value: .fixed(.string(file.sha256))),
                    number("amount", amount)
                ]
            )
        case let .blur(radius): ("blur", [number("radius", radius)])
        case let .sharpen(amount, radius): ("sharpen", [number("amount", amount), number("radius", radius)])
        case let .bloom(amount, radius, color):
            ("bloom", [number("amount", amount), number("radius", radius)] + (color.map { color in
                [TimedMember(key: "color", value: .held(.color(color)))]
            } ?? []))
        case let .vignette(amount, radius): ("vignette", [number("amount", amount), number("radius", radius)])
        case let .pixelate(size): ("pixelate", [number("size", size)])
        case let .grain(amount, size): ("grain", [number("amount", amount), number("size", size)])
        }

        return .form("op:" + name, .object(members))
    }

    func fillColor(at time: Double = 0) -> Color? {
        guard case let .form(_, color) = sampled(at: time, as: LookStructureTable.fill) else { return nil }

        return color.color
    }

    func stroke(at time: Double = 0) -> PathStroke? {
        PathStroke(sampled: sampled(at: time, as: LookStructureTable.stroke))
    }

    func shadow(at time: Double = 0) -> DropShadow? {
        DropShadow(sampled: sampled(at: time, as: LookStructureTable.shadow))
    }

    func border(at time: Double = 0) -> MediaBorder? {
        MediaBorder(sampled: sampled(at: time, as: LookStructureTable.border))
    }

    func filter(at time: Double = 0) -> [FilterEntry] {
        FilterEntry.entries(of: self, at: time)
    }

    func number(at time: Double = 0) -> Double? {
        sampled(at: time, as: LookStructureTable.length).number
    }

    // MARK: - Private
}
