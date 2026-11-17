//
//  ItemOrigin+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `place`, `id` and `kind`, the members `evaluate` and `locate` name an item's clip by, each `null` where no clip
// drew it.
extension Optional where Wrapped == ItemOrigin {
    // MARK: - Property
    var machineOutput: [JSONMember] {
        let text = { (string: String?) in string.map(JSONValue.string) ?? .null }

        return [
            JSONMember(key: "place", value: text(self?.place)),
            JSONMember(key: "id", value: text(self?.id)),
            JSONMember(key: "kind", value: text(self?.kind))
        ]
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
