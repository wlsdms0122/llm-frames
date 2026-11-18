//
//  Parameter.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A published parameter of a template. `options` are a choice's, and empty for any other type.
struct Parameter: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let type: ParameterType
    let defaultValue: JSONValue?
    let options: [String]

    // MARK: - Initializer
    init(
        name: String,
        type: ParameterType,
        defaultValue: JSONValue? = nil,
        options: [String] = []
    ) {
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.options = options
    }

    // MARK: - Public
    // MARK: - Private
}
