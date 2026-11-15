//
//  ArgumentFile.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The arguments a command is given with `--args`, read from the file `name` names, as it was written.
struct ArgumentFile: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let value: JSONValue

    var place: Place {
        Place(file: name, components: [])
    }

    // MARK: - Initializer
    init(
        name: String,
        value: JSONValue
    ) {
        self.name = name
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
