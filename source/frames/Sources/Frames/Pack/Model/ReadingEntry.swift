//
//  ReadingEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// One thing being read on the way to a reference: a file by its path, or a template instance by its template as it
// is named with the value every parameter takes. A template used with other values is another instance, so only the
// same template with the same values repeats.
struct ReadingEntry: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let values: [String: JSONValue]?

    // MARK: - Initializer
    init(
        name: String,
        values: [String: JSONValue]?
    ) {
        self.name = name
        self.values = values
    }

    // MARK: - Public
    // MARK: - Private
}
