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
    package var text: String {
        (["duration \(time(duration))"] + lines(indent: "")).joined(separator: "\n")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func lines(indent: String) -> [String] {
        let storylineLines = storyline.flatMap { entry in
            let transition = entry.transition.map { transition in
                [transition.preset, time(transition.seconds)].compactMap(\.self).joined(separator: " ")
            } ?? "none"
            let line = [
                "\(indent)\(entry.place)",
                entry.media ?? "-",
                "edit \(written(entry.edit))",
                "drawn \(written(entry.drawn))",
                "clip \(written(entry.clip))",
                entry.isTimeRemapped ? "time-remapped" : "speed \(number(entry.speed))",
                "transition \(transition)"
            ].joined(separator: "  ")

            return [line] + (entry.nested?.lines(indent: indent + "  ") ?? [])
        }
        let clipLines = clips.flatMap { entry in
            let animation = entry.animation.map { animation in
                [animation.entrance, animation.loop, animation.exit].map(name(of:)).joined(separator: " / ")
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

    // A span a resolved document keeps without its preset's name is shown by its length.
    private func name(of span: TimelineSpan?) -> String {
        guard let span else { return "-" }

        return span.preset ?? "\(time(span.length))s"
    }

    private func written(_ range: TimeRange) -> String {
        "[\(time(range.start)), \(time(range.end)))"
    }

    // Times are written as the machine output writes them, to the nearest microsecond.
    private func time(_ seconds: Double) -> String {
        JSONValue.time(seconds).written
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}
