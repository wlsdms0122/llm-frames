//
//  Color.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A colour as a value, `#RRGGBBAA` in upper case, so a colour written `#rrggbb` and one written with full alpha are
// the same value.
package struct Color: Equatable, Sendable {
    // MARK: - Property
    package let hex: String

    // MARK: - Initializer
    // `written` is `#RRGGBB` or `#RRGGBBAA`, as the key tables let it through.
    package init(written: String) {
        let digits = written.dropFirst().uppercased()
        self.hex = "#" + (digits.count == 6 ? digits + "FF" : digits)
    }

    // MARK: - Public
    // MARK: - Private
}
