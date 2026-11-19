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

    func number(at time: Double = 0) -> Double? {
        sampled(at: time, as: LookStructureTable.length).number
    }

    // MARK: - Private
}
