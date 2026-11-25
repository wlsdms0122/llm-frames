//
//  ProcessUsage.swift
//  FramesCommand
//
//  Created by JSilver on 11/25/26.
//

import Darwin

// The processor time the process has spent, user and system, on every thread, and the largest resident memory it has
// held, in bytes, as `getrusage` gives them.
struct ProcessUsage: Sendable {
    // MARK: - Property
    let cpuSeconds: Double
    let peakMemory: Int

    // MARK: - Initializer
    // The process's usage now.
    init() {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let seconds = { (time: timeval) in Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }

        self.cpuSeconds = seconds(usage.ru_utime) + seconds(usage.ru_stime)
        // macOS gives the largest resident size in bytes.
        self.peakMemory = Int(usage.ru_maxrss)
    }

    // MARK: - Public
    // MARK: - Private
}
