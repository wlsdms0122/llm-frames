//
//  ToolReader.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import Foundation

// Reads a tool's `tool.json`, whose `run` names an executable file in the tool's directory.
struct ToolReader: Sendable {
    // MARK: - Property
    private let checker = KeyChecker()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func tool(
        named name: String,
        from data: Data,
        in directory: URL
    ) throws -> PackTool {
        let file = directory.appendingPathComponent("tool.json").path
        let place = Place(file: file, components: [])
        let value = try JSONReader(file: file).read(data)
        try checker.check(value, as: PackKeyTable.tool, place: place)

        let object = value.objectValue ?? JSONObject()
        let description = object["description"]?.stringValue ?? ""
        let run = object["run"]?.stringValue ?? ""
        guard !run.contains("/"), !["", ".", ".."].contains(run) else {
            throw PackError.invalidRun(place: place.appending(key: "run"), run: run)
        }

        let executable = directory.appendingPathComponent(run)
        guard isExecutableFile(executable) else {
            throw PackError.unexecutableRun(place: place.appending(key: "run"), run: run)
        }

        return PackTool(name: name, description: description, executable: executable)
    }

    // MARK: - Private
    private func isExecutableFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && FileManager.default.isExecutableFile(atPath: url.path)
    }
}
