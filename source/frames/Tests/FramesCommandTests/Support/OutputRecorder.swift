//
//  OutputRecorder.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation

@testable import FramesCommand

// Keeps what a command writes to standard output and standard error, so a test reads both after it runs.
final class OutputRecorder: @unchecked Sendable {
    // MARK: - Property
    private let lock = NSLock()
    private var written = ""
    private var writtenError = ""

    var standardOutput: String {
        lock.withLock { written }
    }

    var standardError: String {
        lock.withLock { writtenError }
    }

    var output: CommandOutput {
        CommandOutput(
            standardOutput: { [self] text in lock.withLock { written += text } },
            standardError: { [self] text in lock.withLock { writtenError += text } }
        )
    }

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func clear() {
        lock.withLock {
            written = ""
            writtenError = ""
        }
    }

    // MARK: - Private
}
