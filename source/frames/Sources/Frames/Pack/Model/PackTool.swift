//
//  PackTool.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import Foundation

// A tool a pack holds (FRAMES-17 Packs): the name a command gives it (`<pack>/<name>`), the description its
// `tool.json` gives, and the file in its directory that is executed.
package struct PackTool: Equatable, Sendable {
    // MARK: - Property
    package let name: String
    package let description: String
    package let executable: URL

    // MARK: - Initializer
    init(
        name: String,
        description: String,
        executable: URL
    ) {
        self.name = name
        self.description = description
        self.executable = executable
    }

    // MARK: - Public
    // MARK: - Private
}
