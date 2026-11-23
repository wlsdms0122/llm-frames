//
//  ImpulseResponseRefusal.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// What a `convolve` op's file is when it is no sound an impulse response can be: a file without sound, an image
// sequence's directory, a PDF, a sequence document, or sound of no samples or of more than 30 seconds, by the
// duration its probe gives.
enum ImpulseResponseRefusal: Equatable, Sendable {
    case noSound
    case imageSequence
    case page
    case sequence
    case noSamples
    case tooLong(duration: Double)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
