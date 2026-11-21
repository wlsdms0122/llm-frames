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
            "kind \(kind ?? "none")",
            "size \(size.map { "\(number($0.width))x\(number($0.height))" } ?? "none")",
            "duration \(duration.map { JSONValue.time($0).written } ?? "none")",
            "fps \(fps.map(number) ?? "none")",
            "alpha \(hasAlpha.map { $0 ? "yes" : "no" } ?? "none")",
            "color space \(colorSpace.map(written) ?? "none")",
            "audio \(audio ?? "none")",
            "pages \(pageCount.map(String.init) ?? "none")"
        ].joined(separator: "\n")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // The name, or the code points outside the table, then the depth, where the medium stores one, and whether it is
    // HDR.
    private func written(_ colorSpace: ProbedColorSpace) -> String {
        let codePoint = { (value: Int?) in value.map(String.init) ?? "unspecified" }
        let name = colorSpace.name?.rawValue ?? "outside the table (primaries \(codePoint(colorSpace.primaries)), "
            + "transfer \(codePoint(colorSpace.transfer)), matrix \(codePoint(colorSpace.matrix)))"

        let depth = colorSpace.bitDepth.map { ", \($0) bit" } ?? ""

        return "\(name)\(depth)\(colorSpace.isHighDynamicRange ? ", HDR" : "")"
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}
