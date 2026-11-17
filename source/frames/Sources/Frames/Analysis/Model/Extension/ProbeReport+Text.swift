//
//  ProbeReport+Text.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The text `probe` prints for people: one fact a line, `none` where the medium has none. It is not part of the
// contract.
extension ProbeReport {
    // MARK: - Property
    package var text: String {
        let audio = sound.map { sound in
            "\(sound.channels) \(sound.channels == 1 ? "channel" : "channels"), \(number(sound.sampleRate)) Hz"
        }

        return [
            "kind \(kind)",
            "size \(size.map { "\(number($0.width))x\(number($0.height))" } ?? "none")",
            "duration \(duration.map { JSONValue.time($0).written } ?? "none")",
            "fps \(fps.map(number) ?? "none")",
            "alpha \(hasAlpha ? "yes" : "no")",
            "audio \(audio ?? "none")"
        ].joined(separator: "\n")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}
