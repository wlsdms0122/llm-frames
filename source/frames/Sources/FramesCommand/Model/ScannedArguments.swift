//
//  ScannedArguments.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// A command's arguments sorted into its positional arguments, the values of its options and the flags it was given,
// with the rules they were scanned by, so what is missing is named as usage writes it. Times and numbers are decimals,
// and a value that is not one, or is not finite, stops naming its option.
struct ScannedArguments: Equatable, Sendable {
    // MARK: - Property
    let command: String
    private let placeholders: [String]
    private let rules: [OptionRule]
    private let positionals: [String]
    private let values: [String: String]
    private let flags: Set<String>

    // MARK: - Initializer
    init(
        command: String,
        placeholders: [String],
        rules: [OptionRule],
        positionals: [String],
        values: [String: String],
        flags: Set<String>
    ) {
        self.command = command
        self.placeholders = placeholders
        self.rules = rules
        self.positionals = positionals
        self.values = values
        self.flags = flags
    }

    // MARK: - Public
    func positional(at index: Int) -> String? {
        positionals.indices.contains(index) ? positionals[index] : nil
    }

    func requiredPositional(at index: Int) throws -> String {
        guard let argument = positional(at: index) else {
            let placeholder = placeholders.indices.contains(index) ? placeholders[index] : "an argument"
            throw CommandError.missingArgument(command: command, placeholder: placeholder)
        }

        return argument
    }

    func requiredPositionalPath(at index: Int) throws -> String {
        let path = try requiredPositional(at: index)
        guard path.hasPrefix("/") else {
            throw CommandError.relativePath(command: command, option: placeholders[index], path: path)
        }

        return path
    }

    func value(of option: String) -> String? {
        values[option]
    }

    func requiredValue(of option: String) throws -> String {
        guard let value = values[option] else {
            let placeholder = rules.first { $0.name == option }?.value
            throw CommandError.missingOption(command: command, option: option, placeholder: placeholder)
        }

        return value
    }

    func path(of option: String) throws -> String? {
        guard values[option] != nil else { return nil }

        return try requiredPath(of: option)
    }

    // Paths are absolute, so a relative one stops rather than depend on where frames was run from.
    func requiredPath(of option: String) throws -> String {
        let path = try requiredValue(of: option)
        guard path.hasPrefix("/") else {
            throw CommandError.relativePath(command: command, option: option, path: path)
        }

        return path
    }

    func isSet(_ flag: String) -> Bool {
        flags.contains(flag)
    }

    // Seconds.
    func time(of option: String) throws -> Double? {
        guard values[option] != nil else { return nil }

        return try requiredTime(of: option)
    }

    func requiredTime(of option: String) throws -> Double {
        let value = try requiredValue(of: option)
        guard let time = number(value) else { throw invalidValue(of: option, value, expected: "a number of seconds") }

        return time
    }

    // Seconds separated by commas, as `0.5,1,2.25`.
    func requiredTimes(of option: String) throws -> [Double] {
        let value = try requiredValue(of: option)
        let times = value.split(separator: ",", omittingEmptySubsequences: false).map { number(String($0)) }
        guard !times.contains(nil) else {
            throw invalidValue(of: option, value, expected: "seconds separated by commas")
        }

        return times.compactMap(\.self)
    }

    func integer(of option: String) throws -> Int? {
        guard let value = values[option] else { return nil }
        guard let integer = Int(value) else { throw invalidValue(of: option, value, expected: "a whole number") }

        return integer
    }

    // `x,y`.
    func requiredPoint(of option: String) throws -> Point {
        let value = try requiredValue(of: option)
        let coordinates = value.split(separator: ",", omittingEmptySubsequences: false).map { number(String($0)) }
        guard coordinates.count == 2, let horizontal = coordinates[0], let vertical = coordinates[1] else {
            throw invalidValue(of: option, value, expected: "x,y")
        }

        return Point(x: horizontal, y: vertical)
    }

    // BCP 47 tags separated by commas, as `en-US,ko-KR`.
    func languages(of option: String) throws -> [LanguageTag]? {
        guard let value = values[option] else { return nil }
        guard let languages = [LanguageTag](commaSeparated: value) else {
            throw invalidValue(of: option, value, expected: "BCP 47 tags separated by commas")
        }

        return languages
    }

    // One of the values' names, as `--quality high`.
    func choice<Value: RawRepresentable & CaseIterable>(
        of option: String
    ) throws -> Value? where Value.RawValue == String {
        guard let value = values[option] else { return nil }
        guard let choice = Value(rawValue: value) else {
            let names = Value.allCases.map(\.rawValue).joined(separator: ", ")
            throw invalidValue(of: option, value, expected: "one of \(names)")
        }

        return choice
    }

    // The range `--from`, `--to` and `--step` give, a step of a second when `--step` is not given.
    func frameRange() throws -> FrameRange {
        FrameRange(
            from: try time(of: "--from"),
            to: try time(of: "--to"),
            step: try time(of: "--step") ?? 1
        )
    }

    // MARK: - Private
    private func number(_ text: String) -> Double? {
        guard let number = Double(text), number.isFinite else { return nil }

        return number
    }

    private func invalidValue(
        of option: String,
        _ value: String,
        expected: String
    ) -> CommandError {
        CommandError.invalidValue(command: command, option: option, value: value, expected: expected)
    }
}
