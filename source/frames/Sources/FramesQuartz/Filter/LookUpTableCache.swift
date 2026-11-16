//
//  LookUpTableCache.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import os
import Frames

// The LUTs read so far, by pinned file, kept for the renderer's lifetime, so a sequence reads each `.cube` once: when
// its display lists are checked, and not again on every frame.
final class LookUpTableCache: Sendable {
    // MARK: - Property
    private let tables = OSAllocatedUnfairLock<[String: LookUpTable]>(initialState: [:])

    // MARK: - Initializer
    init() {}

    // MARK: - Public
    func table(of file: PinnedFile) throws -> LookUpTable {
        let key = file.sha256 + file.path
        if let table = tables.withLock({ $0[key] }) {
            return table
        }

        let table = LookUpTable(cube: try CubeReader().read(contentsOf: file.path))
        tables.withLock { $0[key] = table }

        return table
    }

    // MARK: - Private
}
