//
//  RunReport.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The report of a run of `render` (FRAMES-23 Runs). `stages` holds every stage: those the render loop timed, the
// decoder's and the encoder's, each summed over the threads that ran it. `readAhead` is the part of `decode` and
// `workingConversion` the decoder ran on threads of its own reading ahead. `waitingOnEncoder` and `waitingOnDecoder`
// are the render's thread's time in the encoder and waiting on the decoder's reading ahead, and `other` the rest of
// `seconds` that no stage on the render's thread and no waiting holds. `memory` is what the run's budget saw
// (FRAMES-30 Report).
package struct RunReport: Equatable, Sendable {
    // MARK: - Property
    package let frames: Int
    package let seconds: Double
    package let cpuSeconds: Double
    package let peakMemory: Int
    package let machine: MachineFacts
    package let roles: RoleNames
    package let stages: StageTimes
    package let readAhead: StageTimes
    package let waitingOnEncoder: Double
    package let waitingOnDecoder: Double
    package let media: [MediumReading]
    package let files: [FileEncoding]
    package let memory: MemoryUsage

    package var framesPerSecond: Double {
        Double(frames) / seconds
    }

    package var cores: Double {
        cpuSeconds / seconds
    }

    package var other: Double {
        seconds - (stages.renderThreadSeconds - readAhead.renderThreadSeconds) - waitingOnEncoder - waitingOnDecoder
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
        readings: MediaReadings,
        memory: MemoryUsage
    ) {
        self.frames = run.frames
        self.seconds = seconds
        self.cpuSeconds = cpuSeconds
        self.peakMemory = peakMemory
        self.machine = machine
        self.roles = roles
        self.stages = run.files.reduce(recorder.stages + readings.seconds) { $0 + $1.seconds }
        self.readAhead = readings.readAhead
        self.waitingOnEncoder = recorder.waitingOnEncoder
        self.waitingOnDecoder = readings.waiting
        self.media = readings.media
        self.files = run.files
        self.memory = memory
    }

    // MARK: - Public
    // MARK: - Private
}
