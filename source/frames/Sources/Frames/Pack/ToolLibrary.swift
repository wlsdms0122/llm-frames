//
//  ToolLibrary.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import Foundation

// Finds the tools packs hold (FRAMES-17 Packs): each a directory `tools/<name>/` of its pack, named `<pack>/<name>`.
// A tool is read and checked each time it is found, as its pack is, since what is installed can change between uses.
// It finds a tool and runs nothing.
package struct ToolLibrary: Sendable {
    // MARK: - Property
    private static let folder = "tools"

    private let packs: PackLibrary
    private let reader = ToolReader()

    // MARK: - Initializer
    package init(packs: PackLibrary) {
        self.packs = packs
    }

    // MARK: - Public
    // The tool `name` names. It is nil where the name is not `<pack>/<name>`, its pack is not there, or the pack holds
    // no tool of that name.
    package func tool(named name: String) throws -> PackTool? {
        guard case let .pack(packName, toolName)? = PackReference(name), let pack = try packs.pack(named: packName) else {
            return nil
        }

        let directory = directory(of: toolName, in: pack)
        guard packs.isDirectory(directory) else { return nil }

        return try tool(named: name, in: directory)
    }

    // Every tool a pack holds, in name order, each read and checked, so a tool that would stop when it is run stops the
    // listing too.
    package func tools(in pack: Pack) throws -> [PackTool] {
        try names(in: pack).map { name in
            try tool(named: "\(pack.name)/\(name)", in: directory(of: name, in: pack))
        }
    }

    // The stop for `name`, which finds no tool, with what the tools that are there say about it.
    package func unknown(named name: String) throws -> UnknownTool {
        try UnknownTool(name: name) { packName in
            try packs.pack(named: packName).map { pack in
                try names(in: pack).map { "\(pack.name)/\($0)" }
            }
        }
    }

    // MARK: - Private
    // The names of the tools a pack holds, in name order. A tool is a directory, so a file in `tools/` is none.
    private func names(in pack: Pack) throws -> [String] {
        try packs.names(in: Self.folder, of: pack, pathExtension: nil).filter { name in
            packs.isDirectory(directory(of: name, in: pack))
        }
    }

    private func directory(
        of name: String,
        in pack: Pack
    ) -> URL {
        pack.directory
            .appendingPathComponent(Self.folder, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    private func tool(
        named name: String,
        in directory: URL
    ) throws -> PackTool {
        let file = directory.appendingPathComponent("tool.json")
        guard let data = try packs.contents(of: file) else {
            throw PackError.missingToolManifest(place: Place(file: file.path, components: []))
        }

        return try reader.tool(named: name, from: data, in: directory)
    }
}
