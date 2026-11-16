//
//  RoleTable.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

// Every implementation of one role or provider by its name, as the global option `option` picks it, and the name
// taken when the option is not given.
struct RoleTable<Builder: Sendable>: Sendable {
    // MARK: - Property
    private let role: String
    private let option: String
    private let defaultName: String
    private let builders: [String: Builder]

    // MARK: - Initializer
    init(
        role: String,
        option: String,
        defaultName: String,
        builders: [String: Builder]
    ) {
        self.role = role
        self.option = option
        self.defaultName = defaultName
        self.builders = builders
    }

    // MARK: - Public
    func builder(named name: String?) throws -> Builder {
        let wanted = name ?? defaultName
        guard let builder = builders[wanted] else {
            throw CommandError.unknownRole(option: option, role: role, name: wanted, known: builders.keys.sorted())
        }

        return builder
    }

    // MARK: - Private
}
