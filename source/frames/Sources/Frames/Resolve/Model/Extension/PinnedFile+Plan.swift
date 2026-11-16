//
//  PinnedFile+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// A file resolve found, pinned by its absolute path and the SHA-256 of its bytes.
extension PinnedFile {
    // MARK: - Property
    // MARK: - Initializer
    // Resolve found every file by its absolute path, and one spelling is kept for each.
    init(
        path: String,
        hashes: any FileHashProvider
    ) throws {
        let absolute = URL(fileURLWithPath: path).standardizedFileURL.path

        self.init(path: absolute, sha256: try hashes.sha256(ofFile: absolute))
    }

    // MARK: - Public
    // MARK: - Private
}
