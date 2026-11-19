//
//  PackLibrary.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Finds packs and the files they hold. Installed packs live in `installed`, and the packs that ship with frames in
// `shipped`, found as if installed.
package struct PackLibrary: Sendable {
    // MARK: - Property
    private let installed: URL
    private let shipped: URL
    private let reader = ManifestReader()

    // MARK: - Initializer
    init(
        installed: URL,
        shipped: URL
    ) {
        self.installed = installed
        self.shipped = shipped
    }

    // Installed packs live at `$FRAMES_HOME/packs`, and `FRAMES_HOME` defaults to `~/.config/frames`.
    package init(
        environment: [String: String],
        shipped: URL
    ) {
        let home = environment["FRAMES_HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: environment["HOME"] ?? NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("frames", isDirectory: true)
        self.init(installed: home.appendingPathComponent("packs", isDirectory: true), shipped: shipped)
    }

    // MARK: - Public
    // A pack is the directory it is in, whatever its manifest calls it. It is checked each time it is used, since what
    // is installed can change between uses.
    package func pack(named name: String) throws -> Pack? {
        let installedDirectory = installed.appendingPathComponent(name, isDirectory: true)
        let shippedDirectory = shipped.appendingPathComponent(name, isDirectory: true)
        let isInstalled = isDirectory(installedDirectory)
        let isShipped = isDirectory(shippedDirectory)
        guard isInstalled || isShipped else { return nil }

        let directory = isInstalled ? installedDirectory : shippedDirectory
        let file = directory.appendingPathComponent("pack.json").path
        let place = Place(file: file, components: [])
        guard !(isInstalled && isShipped) else {
            throw PackError.duplicatePack(place: place, name: name, shipped: shippedDirectory.path)
        }
        guard let data = try contents(of: URL(fileURLWithPath: file)) else {
            throw PackError.missingManifest(place: place)
        }

        let manifest = try reader.manifest(from: data, file: file)
        guard manifest.engine.contains(FramesVersion.current) else {
            throw PackError.unsupportedEngine(
                place: place.appending(key: "engine"),
                pack: name,
                engine: manifest.engine.text,
                version: FramesVersion.current
            )
        }

        return Pack(name: name, directory: directory, manifest: manifest)
    }

    // Every shipped and installed pack, in name order, each checked as it is when it is used.
    package func packs() throws -> [Pack] {
        let names = Set(try entries(in: installed) + entries(in: shipped))

        return try names.sorted().compactMap { try pack(named: $0) }
    }

    // What one of a pack's folders holds, by the names `<pack>/<name>` gives them, in name order. Where its kind of
    // file takes `pathExtension`, the name leaves it out and a file without it is not of that kind.
    package func names(
        in folder: String,
        of pack: Pack,
        pathExtension: String?
    ) throws -> [String] {
        try names(in: pack.directory.appendingPathComponent(folder, isDirectory: true), pathExtension: pathExtension)
    }

    // The names of the files in `directory` that end in `pathExtension`, without it, in name order.
    func names(
        in directory: URL,
        pathExtension: String?
    ) throws -> [String] {
        try entries(in: directory).compactMap { entry in
            guard let pathExtension else { return entry }

            let url = URL(fileURLWithPath: entry)
            guard url.pathExtension == pathExtension else { return nil }

            return url.deletingPathExtension().lastPathComponent
        }
    }

    // The file a reference names: a path as it is, and `<pack>/<name>` in a folder of its pack, with the extension
    // its kind of file takes. A pack that is not there holds nothing.
    package func file(
        of reference: PackReference,
        in folder: String,
        pathExtension: String?
    ) throws -> URL? {
        switch reference {
        case let .path(path):
            return URL(fileURLWithPath: path)

        case let .pack(name, file):
            guard let pack = try pack(named: name) else { return nil }

            let url = pack.directory.appendingPathComponent(folder, isDirectory: true).appendingPathComponent(file)
            return pathExtension.map { url.appendingPathExtension($0) } ?? url
        }
    }

    // The font files in a pack's `fonts/`, in name order, so the face a family is found in does not depend on the
    // order a directory lists them. A pack that is not there, or has no fonts, carries none, and a `fonts/` that is
    // there but cannot be read stops.
    func fontFiles(inPack name: String) throws -> [String] {
        guard let pack = try pack(named: name) else { return [] }

        let directory = pack.directory.appendingPathComponent("fonts", isDirectory: true)

        return try entries(in: directory).map { directory.appendingPathComponent($0).path }
    }

    // A file that is not there is nil, and one that is there but cannot be read stops.
    package func contents(of file: URL) throws -> Data? {
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
            !isDirectory.boolValue
        else {
            return nil
        }
        guard let data = FileManager.default.contents(atPath: file.path) else {
            throw PackError.unreadableFile(file: file.path)
        }

        return data
    }

    func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    // MARK: - Private
    // What a directory holds, in name order, so a listing does not depend on the order the disk gives. A hidden entry,
    // such as `.gitkeep` or `.DS_Store`, is not part of what it holds. A directory that is not there holds nothing, and
    // one that is there but cannot be read stops.
    private func entries(in directory: URL) throws -> [String] {
        guard isDirectory(directory) else { return [] }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            throw PackError.unreadableFile(file: directory.path)
        }

        return names.filter { !$0.hasPrefix(".") }.sorted()
    }
}
