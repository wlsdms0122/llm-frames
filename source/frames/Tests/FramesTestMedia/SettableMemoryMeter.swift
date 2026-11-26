//
//  SettableMemoryMeter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/26/26.
//

import Frames
import os

// A meter whose reading a test sets: the footprint it gives, 0 until set, and the moment, which moves only when the
// test moves it. Its peak is the largest footprint set. Used from any thread.
package final class SettableMemoryMeter: MemoryMeter {
    // MARK: - Property
    private let state: OSAllocatedUnfairLock<MemoryReading>

    // MARK: - Initializer
    package init() {
        state = OSAllocatedUnfairLock(initialState: MemoryReading(footprint: 0, peak: 0, time: .now))
    }

    // MARK: - Public
    package func read() -> MemoryReading {
        state.withLock { $0 }
    }

    // The process holds `bytes` from now on.
    package func set(_ bytes: Int) {
        state.withLock { reading in
            reading = MemoryReading(footprint: bytes, peak: max(reading.peak, bytes), time: reading.time)
        }
    }

    // Moves the moment of the readings on by `duration`.
    package func advance(by duration: Duration) {
        state.withLock { reading in
            reading = MemoryReading(footprint: reading.footprint, peak: reading.peak, time: reading.time + duration)
        }
    }

    // MARK: - Private
}
