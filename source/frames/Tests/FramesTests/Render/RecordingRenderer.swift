//
//  RecordingRenderer.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// Draws each list as a bitmap carrying its frame number.
struct RecordingRenderer: Renderer {
    // MARK: - Property
    let log: RoleCallLog
    let refuses: Bool

    // MARK: - Initializer
    init(
        log: RoleCallLog,
        refuses: Bool = false
    ) {
        self.log = log
        self.refuses = refuses
    }

    // MARK: - Lifecycle
    func check(_ list: DisplayList) throws {
        log.record(.checkList(frame: list.seed))
        guard !refuses else { throw RoleRefusal.renderer }
    }

    func frame(of list: DisplayList) throws -> Bitmap {
        log.record(.draw(frame: list.seed))

        return Bitmap(frame: list.seed)
    }

    // MARK: - Public
    // MARK: - Private
}
