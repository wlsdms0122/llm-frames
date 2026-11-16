//
//  RecordingMixer.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// Mixes silence at 48 kHz in stereo, `duration` long.
struct RecordingMixer: Mixer {
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
    func check(_ plan: MixPlan) throws {
        log.record(.checkPlan(plan))
        guard !refuses else { throw RoleRefusal.mixer }
    }

    func mix(
        _ plan: MixPlan,
        duration: Double
    ) throws -> SoundBuffer {
        log.record(.mix(duration: duration))

        return SoundBuffer(
            sampleRate: 48_000,
            channels: 2,
            samples: Array(repeating: 0, count: Int((duration * 48_000).rounded()) * 2)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
