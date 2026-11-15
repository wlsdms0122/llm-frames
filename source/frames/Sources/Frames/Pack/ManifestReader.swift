//
//  ManifestReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Reads a pack's `pack.json`.
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
        let value = try JSONReader(file: file).read(data)
        try checker.check(value, as: PackKeyTable.manifest, place: place)

        let manifest = value.objectValue ?? JSONObject()
        let engine = manifest["engine"]?.stringValue ?? ""
        guard let range = EngineRange(engine) else {
            throw PackError.invalidEngine(place: place.appending(key: "engine"), engine: engine)
        }

        return PackManifest(
            name: manifest["name"]?.stringValue,
            version: manifest["version"]?.stringValue,
            description: manifest["description"]?.stringValue,
            engine: range
        )
    }

    // MARK: - Private
}
