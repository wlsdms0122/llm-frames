//
//  JSONObject.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Members keep the order they were written in, so the first unknown key is the first one in the file.
package struct JSONObject: Equatable, Sendable {
    // MARK: - Property
    let members: [JSONMember]

    var keys: [String] {
        members.map(\.key)
    }

    // MARK: - Initializer
    init(members: [JSONMember] = []) {
        self.members = members
    }

    // MARK: - Public
    subscript(key: String) -> JSONValue? {
        members.first { $0.key == key }?.value
    }

    func contains(_ key: String) -> Bool {
        members.contains { $0.key == key }
    }

    func setting(_ key: String, to value: JSONValue) -> JSONObject {
        guard contains(key) else {
            return JSONObject(members: members + [JSONMember(key: key, value: value)])
        }

        return JSONObject(members: members.map { member in
            member.key == key ? JSONMember(key: key, value: value) : member
        })
    }

    // MARK: - Private
}
