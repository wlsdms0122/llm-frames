//
//  TemporaryDirectory.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// A directory a test writes its media into, removed when the test lets go of it.
package final class TemporaryDirectory: Sendable {
    // MARK: - Property
    package let path: String

    // MARK: - Initializer
    package init() throws {
        path = FileManager.default.temporaryDirectory.appendingPathComponent("frames-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Public
    package func file(_ name: String) -> String {
        (path as NSString).appendingPathComponent(name)
    }

    // MARK: - Private
}
