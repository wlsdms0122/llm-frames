//
//  TOMLReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Reads the TOML subset open-package writes a manifest in into the tree a JSON file reads into, each table an
// object: one level of `[table]` headers, and `key = value` on one line, with a string, an integer, true or false, or
// a list of them. Anything else is refused with its line rather than taken for some other shape.
struct TOMLReader: Sendable {
    // MARK: - Property
    private let file: String

    // MARK: - Initializer
    init(file: String) {
        self.file = file
    }

    // MARK: - Public
    func read(_ data: Data) throws -> JSONValue {
        guard let source = String(data: data, encoding: .utf8) else {
            throw PackError.manifestSyntax(file: file, line: 1, reason: "the file is not UTF-8")
        }

        var root = JSONObject()
        // Nil before the first header, so a key outside any table is refused, not stored.
        var table: String?
        for (offset, line) in lines(of: source).enumerated() {
            let number = offset + 1
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("[") {
                let name = try header(line, line: number)
                table = name
                root = root.setting(name, to: root[name] ?? .object(JSONObject()))
                continue
            }

            let (key, value) = try assignment(line, line: number)
            guard let table else {
                throw PackError.manifestSyntax(
                    file: file,
                    line: number,
                    reason: "\(quoted(key)) is written before any [table] header"
                )
            }

            let object = root[table]?.objectValue ?? JSONObject()
            guard !object.contains(key) else {
                throw PackError.manifestSyntax(
                    file: file,
                    line: number,
                    reason: "\(quoted("\(table).\(key)")) is written twice"
                )
            }

            root = root.setting(table, to: .object(object.setting(key, to: value)))
        }

        return .object(root)
    }

    // MARK: - Private
    // `isNewline` keeps CRLF one line break, so every line number stays right.
    private func lines(of source: String) -> [String] {
        source
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func header(
        _ line: String,
        line number: Int
    ) throws -> String {
        // Checked before the brackets are taken off, or `[[command]]` would read as a table named `[command]`.
        guard !line.hasPrefix("[[") else {
            throw PackError.manifestSyntax(file: file, line: number, reason: "an array of tables is not read here")
        }
        guard line.hasSuffix("]") else {
            throw PackError.manifestSyntax(file: file, line: number, reason: "a table header is not closed with \"]\"")
        }

        let name = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        guard !name.contains(".") else {
            throw PackError.manifestSyntax(
                file: file,
                line: number,
                reason: "\(quoted(name)) is a nested table, and tables here have one level"
            )
        }
        try checkName(name, role: "table name", line: number)

        return name
    }

    private func assignment(
        _ line: String,
        line number: Int
    ) throws -> (key: String, value: JSONValue) {
        guard let separator = line.firstIndex(of: "=") else {
            throw PackError.manifestSyntax(file: file, line: number, reason: "expected key = value, found \(line)")
        }

        let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
        // A dotted key would be a second way to write a table.
        guard !key.contains(".") else {
            throw PackError.manifestSyntax(
                file: file,
                line: number,
                reason: "\(quoted(key)) is a dotted key. Write a [table] header"
            )
        }
        try checkName(key, role: "key", line: number)

        var cursor = TOMLCursor(text: String(line[line.index(after: separator)...]), file: file, line: number)
        let value = try cursor.value()
        try cursor.expectEnd()

        return (key, value)
    }

    // A name is written plainly or not at all, so a quoted one is not stored under a key nothing looks up.
    private func checkName(
        _ name: String,
        role: String,
        line number: Int
    ) throws {
        guard !name.isEmpty else {
            throw PackError.manifestSyntax(file: file, line: number, reason: "empty \(role)")
        }
        guard name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
            throw PackError.manifestSyntax(file: file, line: number, reason: "\(quoted(name)) is not a \(role)")
        }
    }

    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }
}
