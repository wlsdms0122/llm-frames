//
//  TimedValue+Pinned.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A timed filter with each LUT's and displacement map's file pinned: its absolute path with the SHA-256 of what it
// holds beside it.
extension TimedValue {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func pinningFiles(hashes: any FileHashProvider) throws -> TimedValue {
        switch self {
        case .off, .fixed, .track:
            return self

        case let .object(members):
            return .object(try members.map { TimedMember(key: $0.key, value: try $0.value.pinningFiles(hashes: hashes)) })

        case let .list(elements):
            return .list(try elements.map { try $0.pinningFiles(hashes: hashes) })

        case let .form(name, .object(members)) where name == "op:lut" || name == "op:displace":
            return .form(name, .object(try members.flatMap { member -> [TimedMember] in
                guard member.key == "file", case let .fixed(.string(path)) = member.value else { return [member] }

                let file = try PinnedFile(path: path, hashes: hashes)
                return [
                    TimedMember(key: "file", value: .fixed(.string(file.path))),
                    TimedMember(key: "sha256", value: .fixed(.string(file.sha256)))
                ]
            }))

        case let .form(name, body):
            return .form(name, try body.pinningFiles(hashes: hashes))
        }
    }

    // MARK: - Private
}
