//
//  DocumentFile.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A checked document read from a file, a document named where media is taken. `name` is how it was referred to,
// which its places name, and `file` is the path it was read from.
struct DocumentFile: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let file: String
    let value: JSONValue

    var place: Place {
        Place(file: name, components: [])
    }

    // MARK: - Initializer
    init(
        name: String,
        file: String,
        value: JSONValue
    ) {
        self.name = name
        self.file = file
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
