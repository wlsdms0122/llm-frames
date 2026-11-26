//
//  MemoryMeter.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// Reads the memory the process holds, as the system counts it, for a run's budget (FRAMES-30 What it measures).
package protocol MemoryMeter: Sendable {
    // The process's footprint now, the largest it has been, and the moment of the reading.
    func read() -> MemoryReading
}
