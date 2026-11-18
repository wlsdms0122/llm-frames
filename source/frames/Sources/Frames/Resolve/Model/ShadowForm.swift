//
//  ShadowForm.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A `shadow` as written: `true`, the theme `shadow`, `{radius, offset, color}` with the keys it leaves out nil, which
// come from the theme `shadow`, or `false`.
enum ShadowForm: Equatable, Sendable {
    case shadow(radius: Double?, offset: Point?, color: String?)
    case off

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        if let isDrawn = value.boolValue {
            self = isDrawn ? .shadow(radius: nil, offset: nil, color: nil) : .off
            return
        }
        guard let object = value.objectValue else { return nil }

        let offset = object["offset"]?.arrayValue?.compactMap(\.numberValue)
        self = .shadow(
            radius: object["radius"]?.numberValue,
            offset: offset.flatMap { $0.count == 2 ? Point(x: $0[0], y: $0[1]) : nil },
            color: object["color"]?.stringValue
        )
    }

    // MARK: - Public
    // MARK: - Private
}
