//
//  ManifestReader.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

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
        let kind = PackKeyTable.manifestKind
        let object = try TOMLReader(file: file).read(data).objectValue ?? JSONObject()

        let openPackagePlace = place.appending(key: PackKeyTable.openPackage)
        guard let openPackage = object[PackKeyTable.openPackage] else {
            throw ModelError.missingKey(place: place, kind: kind, keys: [PackKeyTable.openPackage])
        }
        try checker.check(openPackage, as: .anyObject, place: openPackagePlace, kind: kind)
        guard let name = openPackage.objectValue?["name"] else {
            throw ModelError.missingKey(place: openPackagePlace, kind: kind, keys: ["name"])
        }
        try checker.check(name, as: .name, place: openPackagePlace.appending(key: "name"), kind: kind)

        let framesPlace = place.appending(key: "frames")
        guard let frames = object["frames"] else {
            throw ModelError.missingKey(place: place, kind: kind, keys: ["frames"])
        }
        try checker.check(frames, as: PackKeyTable.frames, place: framesPlace)
        let engine = frames.objectValue?["engine"]?.stringValue ?? ""
        guard let range = EngineRange(engine) else {
            throw PackError.invalidEngine(place: framesPlace.appending(key: "engine"), engine: engine)
        }

        return PackManifest(name: name.stringValue ?? "", engine: range)
    }

    // MARK: - Private
}
