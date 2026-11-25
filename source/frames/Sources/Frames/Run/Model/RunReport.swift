//
//  RunReport.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The report of a run of `render` (FRAMES-23 Runs). `stages` holds every stage: those the render loop timed, the
// decoder's and the encoder's. `waiting` is the render's thread's time in the encoder, and `other` the rest of
// `seconds` that no stage of the render's thread and no waiting holds.
package struct RunReport: Equatable, Sendable {
    // MARK: - Property
    package let frames: Int
    package let seconds: Double
    package let cpuSeconds: Double
    package let peakMemory: Int
    package let machine: MachineFacts
    package let roles: RoleNames
    package let stages: StageTimes
    package let waiting: Double
    package let media: [MediumReading]
    package let files: [FileEncoding]

    package var framesPerSecond: Double {
        Double(frames) / seconds
    }

    package var cores: Double {
        cpuSeconds / seconds
    }

    package var other: Double {
        seconds - stages.renderThreadSeconds - waiting
    }

    // MARK: - Initializer
    package init(
        run: RenderRun,
        seconds: Double,
        cpuSeconds: Double,
        peakMemory: Int,
        machine: MachineFacts,
        roles: RoleNames,
        recorder: RunRecorder,
        readings: MediaReadings
    ) {
        self.frames = run.frames
        self.seconds = seconds
        self.cpuSeconds = cpuSeconds
        self.peakMemory = peakMemory
        self.machine = machine
        self.roles = roles
        self.stages = run.files.reduce(recorder.stages + readings.seconds) { $0 + $1.seconds }
        self.waiting = recorder.waiting
        self.media = readings.media
        self.files = run.files
    }

    // MARK: - Public
    // MARK: - Private
}
