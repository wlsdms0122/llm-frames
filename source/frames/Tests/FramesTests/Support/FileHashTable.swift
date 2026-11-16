//
//  FileHashTable.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

@testable import Frames

// A fake hasher for files that are only named: a file's digest is the one given, or a digest made from its path, so
// every named file is pinned and the same path always gives the same digest.
struct FileHashTable: FileHashProvider {
    // MARK: - Property
    let digests: [String: String]

    // MARK: - Initializer
    init(_ digests: [String: String] = [:]) {
        self.digests = digests
    }

    // MARK: - Public
    func sha256(ofFile path: String) throws -> String {
        digests[path] ?? "sha256-of-" + path
    }

    // MARK: - Private
}
