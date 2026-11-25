//
//  MachineFacts.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The machine a run ran on: its processor's name as the system gives it, its logical cores, and its operating system's
// name and version.
package struct MachineFacts: Equatable, Sendable {
    // MARK: - Property
    package let chip: String
    package let cores: Int
    package let operatingSystem: String

    // MARK: - Initializer
    package init(
        chip: String,
        cores: Int,
        operatingSystem: String
    ) {
        self.chip = chip
        self.cores = cores
        self.operatingSystem = operatingSystem
    }

    // MARK: - Public
    // MARK: - Private
}
