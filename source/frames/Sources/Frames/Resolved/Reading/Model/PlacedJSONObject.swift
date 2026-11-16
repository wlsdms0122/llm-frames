//
//  PlacedJSONObject.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A JSON object with its place in the file and the kind of entry it belongs to. A member is read with its place, and
// a missing one stops, naming the object's place and the key.
struct PlacedJSONObject: Sendable {
    // MARK: - Property
    let object: JSONObject
    let place: Place
    let kind: String

    // MARK: - Initializer
    init(
        _ object: JSONObject,
        place: Place,
        kind: String
    ) {
        self.object = object
        self.place = place
        self.kind = kind
    }

    // MARK: - Public
    func member(_ key: String) throws -> PlacedJSONValue {
        guard let value = object[key] else { throw ModelError.missingKey(place: place, kind: kind, keys: [key]) }

        return PlacedJSONValue(value, place: place.appending(key: key), kind: kind)
    }

    // A member resolve writes only for some entries, nil where it is not written.
    func optionalMember(_ key: String) -> PlacedJSONValue? {
        object[key].map { PlacedJSONValue($0, place: place.appending(key: key), kind: kind) }
    }

    func contains(_ key: String) -> Bool {
        object.contains(key)
    }

    // MARK: - Private
}
