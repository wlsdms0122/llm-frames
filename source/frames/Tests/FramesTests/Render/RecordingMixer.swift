//
//  RecordingMixer.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// Mixes `level(n)` on both channels at each sample n at 48 kHz in stereo, the plan's `length` samples per channel,
// silence unless a level is given.
struct RecordingMixer: Mixer {
    // MARK: - Property
    let log: RoleCallLog
    let refuses: Bool
    let level: @Sendable (Int) -> Float

    // MARK: - Initializer
    init(
        log: RoleCallLog,
        refuses: Bool = false,
        level: @escaping @Sendable (Int) -> Float = { _ in 0 }
    ) {
        self.log = log
        self.refuses = refuses
        self.level = level
    }

    // MARK: - Lifecycle
    func check(_ plan: MixPlan) throws {
        log.record(.checkPlan(plan))
        guard !refuses else { throw RoleRefusal.mixer }
    }

    func mix(_ plan: MixPlan) throws -> SoundBuffer {
        log.record(.mix(length: plan.length))

        return SoundBuffer(
            sampleRate: 48_000,
            channels: 2,
            samples: (0..<plan.length).flatMap { sample in [level(sample), level(sample)] }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
