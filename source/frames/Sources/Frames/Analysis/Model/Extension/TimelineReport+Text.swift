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
        let header = ["duration \(seconds(duration))"] + (time.map { ["at \(seconds($0))"] } ?? [])

        return (header + lines(indent: "")).joined(separator: "\n")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func lines(indent: String) -> [String] {
        let storylineLines = storyline.flatMap { entry in
            let transition = entry.transition.map { transition in
                [transition.preset, seconds(transition.seconds)].compactMap(\.self).joined(separator: " ")
            } ?? "none"
            let line = [
                "\(indent)\(entry.place)",
                entry.kind,
                media(entry.media, page: entry.page),
                "edit \(written(entry.edit))",
                "drawn \(written(entry.drawn))",
                "clip \(written(entry.clip))",
                "sound \(entry.sound.map(written) ?? "-")",
                entry.isTimeRemapped ? "time-remapped" : "speed \(number(entry.speed))",
                "transition \(transition)"
            ] + (entry.time.map { time in
                ["clip time \(seconds(time.clipTime))", "media time \(media(time: time.mediaTime))"] + written(time.geometry)
            } ?? [])
            let joined = line.joined(separator: "  ")

            return [joined] + (entry.nested?.lines(indent: indent + "  ") ?? [])
        }
        let clipLines = clips.flatMap { entry in
            let animation = entry.animation.map { animation in
                [animation.entrance, animation.loop, animation.exit].map(name(of:)).joined(separator: " / ")
            } ?? "none"
            let line = [
                "\(indent)\(entry.place)",
                entry.kind,
                media(entry.media, page: entry.page),
                "visible \(written(entry.visible))",
                "sound \(entry.sound.map(written) ?? "-")",
                "lane \(entry.lane.map(String.init) ?? "-")",
                "parent \(entry.parent ?? "-")",
                "animation \(animation)"
            ] + (entry.time.map { ["media time \(media(time: $0.mediaTime))"] + written($0.geometry) } ?? [])

            return [line.joined(separator: "  ")] + (entry.nested?.lines(indent: indent + "  ") ?? [])
        }

        return storylineLines + clipLines
    }

    // A span a resolved document keeps without its preset's name is shown by its length.
    private func name(of span: TimelineSpan?) -> String {
        guard let span else { return "-" }

        return span.preset ?? "\(seconds(span.length))s"
    }

    private func media(
        _ media: String?,
        page: Int?
    ) -> String {
        media.map { media in page.map { "\(media) page \($0)" } ?? media } ?? "-"
    }

    private func media(time: Double?) -> String {
        time.map(seconds) ?? "-"
    }

    // A box as its rect and the quad it lies on, and each mask as its quad.
    private func written(_ geometry: TimelineGeometry) -> [String] {
        let box = geometry.box.map { "box \(written(rect: $0.rect)) on \(written($0.quad))" } ?? "box -"
        let masks = geometry.masks.map { masks in
            masks.isEmpty ? "masks none" : "masks " + masks.map(written).joined(separator: " ")
        } ?? "masks -"

        return [box, masks]
    }

    private func written(rect: Rectangle) -> String {
        "[" + [rect.x, rect.y, rect.width, rect.height].map(measure).joined(separator: ", ") + "]"
    }

    private func written(_ quad: Quad) -> String {
        "[" + quad.corners.map { "[\(measure($0.x)), \(measure($0.y))]" }.joined(separator: ", ") + "]"
    }

    private func measure(_ value: Double) -> String {
        JSONValue.measure(value).written
    }

    private func written(_ range: TimeRange) -> String {
        "[\(seconds(range.start)), \(seconds(range.end)))"
    }

    // Times are written as the machine output writes them, to the nearest microsecond.
    private func seconds(_ seconds: Double) -> String {
        JSONValue.time(seconds).written
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}
