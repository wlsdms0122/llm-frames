//
//  FontWeight.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A weight from 100 to 900, as CSS `font-weight` and the OpenType weight class give it.
package struct FontWeight: Equatable, Hashable, Sendable {
    // MARK: - Property
    // The names of the OpenType weight classes, as a theme style may write them.
    static let names: [(name: String, value: Int)] = [
        ("thin", 100),
        ("extralight", 200),
        ("light", 300),
        ("regular", 400),
        ("medium", 500),
        ("semibold", 600),
        ("bold", 700),
        ("extrabold", 800),
        ("black", 900)
    ]

    package static let regular = FontWeight(400)
    package static let bold = FontWeight(700)

    package let value: Int

    // The weight's name, or its number when it has none.
    package var written: String {
        Self.names.first { $0.value == value }?.name ?? "\(value)"
    }

    // MARK: - Initializer
    package init(_ value: Int) {
        self.value = value
    }

    // A weight as a style writes it, a number or a name, which the key tables checked.
    init?(written: JSONValue) {
        if let number = written.numberValue, let value = Int(exactly: number) {
            self.init(value)
        } else if let name = written.stringValue, let value = Self.names.first(where: { $0.name == name })?.value {
            self.init(value)
        } else {
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
