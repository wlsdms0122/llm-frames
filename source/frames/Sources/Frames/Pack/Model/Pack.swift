//
//  Pack.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// A found pack: the name of its directory, which is how documents name it, the directory that holds its folders, and
// its manifest.
package struct Pack: Equatable, Sendable {
    // MARK: - Property
    package let name: String
    package let directory: URL
    package let manifest: PackManifest

    // MARK: - Initializer
    init(
        name: String,
        directory: URL,
        manifest: PackManifest
    ) {
        self.name = name
        self.directory = directory
        self.manifest = manifest
    }

    // MARK: - Public
    // MARK: - Private
}
