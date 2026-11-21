//
//  RecordingRenderer.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// Draws each list as a bitmap carrying its frame number. `refusesSamples` refuses a list given as samples, as a renderer
// that cannot draw their mean does.
struct RecordingRenderer: Renderer {
    // MARK: - Property
    let log: RoleCallLog
    let refuses: Bool
    let refusesSamples: Bool

    // MARK: - Initializer
    init(
        log: RoleCallLog,
        refuses: Bool = false,
        refusesSamples: Bool = false
    ) {
        self.log = log
        self.refuses = refuses
        self.refusesSamples = refusesSamples
    }

    // MARK: - Lifecycle
    func check(_ list: DisplayList) throws {
        log.record(.checkList(frame: list.seed))
        guard !refuses, !refusesSamples || list.samples == nil else { throw RoleRefusal.renderer }
    }

    func frame(of list: DisplayList) throws -> Bitmap {
        log.record(.draw(frame: list.seed))

        return Bitmap(frame: list.seed)
    }

    // MARK: - Public
    // MARK: - Private
}
