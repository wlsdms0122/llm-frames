//
//  Pack.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// A found pack: its name and the directory that holds its folders.
struct Pack: Equatable, Sendable {
    // MARK: - Property
    let name: String
    let directory: URL

    // MARK: - Initializer
    init(
        name: String,
        directory: URL
    ) {
        self.name = name
        self.directory = directory
    }

    // MARK: - Public
    // MARK: - Private
}
