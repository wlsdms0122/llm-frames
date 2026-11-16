//
//  PackReference.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The spellings a name takes: an absolute path, `<pack>/<name>`, or a bare name, which is built in.
package enum PackReference: Equatable, Sendable {
    case path(String)
    case pack(pack: String, name: String)
    case builtIn(String)

    // MARK: - Property
    // MARK: - Initializer
    // Any other spelling names nothing: more than one slash, or an empty, `.` or `..` part, which would leave the pack.
    package init?(_ reference: String) {
        guard !reference.hasPrefix("/") else {
            self = .path(reference)
            return
        }

        let parts = reference.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard (1...2).contains(parts.count), parts.allSatisfy({ !["", ".", ".."].contains($0) }) else { return nil }

        self = parts.count == 1 ? .builtIn(parts[0]) : .pack(pack: parts[0], name: parts[1])
    }

    // MARK: - Public
    // MARK: - Private
}
