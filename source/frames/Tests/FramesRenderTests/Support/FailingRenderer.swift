//
//  FailingRenderer.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

// A renderer that draws through another one and fails one frame, so a render stops half way with its writers open.
final class FailingRenderer: Renderer, @unchecked Sendable {
    // MARK: - Property
    private let renderer: any Renderer
    private let failingFrame: Int
    private let lock = NSLock()
    private var frameCount = 0

    // MARK: - Initializer
    init(
        renderer: any Renderer,
        failingAt failingFrame: Int
    ) {
        self.renderer = renderer
        self.failingFrame = failingFrame
    }

    // MARK: - Lifecycle
    func check(_ list: DisplayList) throws {
        try renderer.check(list)
    }

    func pictureBytes(of list: DisplayList) throws -> Int {
        try renderer.pictureBytes(of: list)
    }

    func frame(of list: DisplayList) throws -> Pixels {
        let index = lock.withLock {
            defer { frameCount += 1 }

            return frameCount
        }
        guard index != failingFrame else { throw InjectedFailure.frame(index) }

        return try renderer.frame(of: list)
    }

    // MARK: - Public
    // MARK: - Private
}
