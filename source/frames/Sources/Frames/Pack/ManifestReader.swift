//
//  ManifestReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Reads a pack's `manifest.toml` as open-package writes it, with the `[frames]` table frames adds.
struct ManifestReader: Sendable {
    // MARK: - Property
    private let checker = KeyChecker()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func manifest(
        from data: Data,
        file: String
    ) throws -> PackManifest {
        let place = Place(file: file, components: [])
        let manifest = try TOMLReader(file: file).read(data).objectValue ?? JSONObject()

        _ = try table("open-package", in: manifest, as: PackKeyTable.openPackage, place: place, isOpen: true)
        let package = try table("package", in: manifest, as: PackKeyTable.package, place: place, isOpen: true)
        let frames = try table("frames", in: manifest, as: PackKeyTable.frames, place: place, isOpen: false)

        let engine = frames["engine"]?.stringValue ?? ""
        guard let range = EngineRange(engine) else {
            throw PackError.invalidEngine(
                place: place.appending(key: "frames").appending(key: "engine"),
                engine: engine
            )
        }

        return PackManifest(
            name: package["name"]?.stringValue ?? "",
            version: package["version"]?.stringValue ?? "",
            description: package["description"]?.stringValue,
            engine: range
        )
    }

    // MARK: - Private
    // An open table is checked only for the keys frames reads, since the others are open-package's.
    private func table(
        _ name: String,
        in manifest: JSONObject,
        as table: ObjectTable,
        place: Place,
        isOpen: Bool
    ) throws -> JSONObject {
        guard let object = manifest[name]?.objectValue else {
            throw ModelError.missingKey(place: place, kind: table.kind, keys: [name])
        }

        let tablePlace = place.appending(key: name)
        guard isOpen else {
            try checker.check(.object(object), as: table, place: tablePlace)
            return object
        }

        for rule in table.rules {
            guard let value = object[rule.name] else {
                guard !rule.isRequired else {
                    throw ModelError.missingKey(place: tablePlace, kind: table.kind, keys: [rule.name])
                }

                continue
            }

            try checker.check(value, as: rule.type, place: tablePlace.appending(key: rule.name), kind: table.kind)
        }

        return object
    }
}
