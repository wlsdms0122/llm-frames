//
//  CornerRadii+Written.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// The forms a corner `radius` is written in (FRAMES-11 Shapes): one number, the radius of every corner, or four
// numbers, `[topLeft, topRight, bottomRight, bottomLeft]`.
extension CornerRadii {
    // MARK: - Property
    // MARK: - Initializer
    // `written` is one of the two forms, as the key tables let it through, and nothing written is no radius.
    init(written: JSONValue) {
        if let number = written.numberValue {
            self.init(number)
        } else {
            self = CornerRadii(values: (written.arrayValue ?? []).compactMap(\.numberValue)) ?? .zero
        }
    }

    // MARK: - Public
    // MARK: - Private
}
