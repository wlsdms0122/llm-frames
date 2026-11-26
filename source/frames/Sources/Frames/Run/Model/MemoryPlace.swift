//
//  MemoryPlace.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// Where the memory a budget's holder counts lies: in frames's process, whose footprint the budget measures, or in the
// decoding service the platform runs for the process, which the budget counts by the decoder's model (FRAMES-30 What
// it measures).
package enum MemoryPlace: Equatable, Sendable {
    case process
    case decodingService

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
