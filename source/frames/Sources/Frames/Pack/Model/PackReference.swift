//
//  PackReference.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The spellings a name takes: an absolute path or `<pack>/<name>`.
package enum PackReference: Equatable, Sendable {
    case path(String)
    case pack(pack: String, name: String)

    // MARK: - Property
    // MARK: - Initializer
    // Any other spelling names nothing: no slash or more than one, or an empty, `.` or `..` part, which would leave the
    // pack.
    package init?(_ reference: String) {
        guard !reference.hasPrefix("/") else {
            self = .path(reference)
            return
        }

        let parts = reference.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, parts.allSatisfy({ !["", ".", ".."].contains($0) }) else { return nil }

        self = .pack(pack: parts[0], name: parts[1])
    }

    // MARK: - Public
    // MARK: - Private
}
