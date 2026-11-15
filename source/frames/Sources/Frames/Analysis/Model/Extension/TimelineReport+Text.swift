//
//  TimelineReport+Text.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The text `timeline` prints for people: one line per clip, with a nested document's lines indented under its clip.
// It is not part of the contract.
extension TimelineReport {
    // MARK: - Property
    var text: String {
        (["duration \(number(duration))"] + lines(indent: "")).joined(separator: "\n")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func lines(indent: String) -> [String] {
        let storylineLines = storyline.flatMap { entry in
            let transition = entry.transition.map { "\($0.preset) \(number($0.seconds))" } ?? "none"
            let line = [
                "\(indent)\(entry.place)",
                entry.media ?? "-",
                "edit \(written(entry.edit))",
                "drawn \(written(entry.drawn))",
                "clip \(written(entry.clip))",
                "speed \(number(entry.speed))",
                "transition \(transition)"
            ].joined(separator: "  ")

            return [line] + (entry.nested?.lines(indent: indent + "  ") ?? [])
        }
        let clipLines = clips.flatMap { entry in
            let animation = entry.animation.map { animation in
                [animation.entrance, animation.loop, animation.exit].map { $0 ?? "-" }.joined(separator: " / ")
            } ?? "none"
            let line = [
                "\(indent)\(entry.place)",
                entry.kind,
                "visible \(written(entry.visible))",
                "animation \(animation)"
            ].joined(separator: "  ")

            return [line] + (entry.nested?.lines(indent: indent + "  ") ?? [])
        }

        return storylineLines + clipLines
    }

    private func written(_ range: TimeRange) -> String {
        "[\(number(range.start)), \(number(range.end)))"
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}
