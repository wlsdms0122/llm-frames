//
//  StrokeForm.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape's `stroke` as written: `{color, width, join, cap, start, end}` with the keys it leaves out nil, or `false`,
// which turns off its style's stroke.
enum StrokeForm: Equatable, Sendable {
    case stroke(color: String?, width: Double, join: StrokeJoin?, cap: StrokeCap?, start: StrokeEnd?, end: StrokeEnd?)
    case off

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        if let object = value.objectValue, let width = object["width"]?.numberValue {
            self = .stroke(
                color: object["color"]?.stringValue,
                width: width,
                join: object["join"]?.stringValue.flatMap(StrokeJoin.init),
                cap: object["cap"]?.stringValue.flatMap(StrokeCap.init),
                start: object["start"]?.stringValue.flatMap(StrokeEnd.init),
                end: object["end"]?.stringValue.flatMap(StrokeEnd.init)
            )
            return
        }
        guard value.boolValue == false else { return nil }

        self = .off
    }

    // MARK: - Public
    // MARK: - Private
}
