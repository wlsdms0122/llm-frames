//
//  ResolvedText+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Text as set, with the font file of each run pinned.
extension ResolvedText {
    // MARK: - Property
    // MARK: - Initializer
    // A title takes each run's attributes from the timed value of its text run. An underline leaf no layer gives
    // takes the run's colour.
    init(
        plan: TitlePlan,
        hashes: any FileHashProvider
    ) throws {
        self.init(
            size: plan.layout.size,
            background: plan.layout.background,
            runs: try plan.layout.runs.map { run in
                let character = plan.characters[run.source]
                let color = character["color"] ?? .off

                return ResolvedGlyphRun(
                    font: try PinnedFile(path: run.face.file, hashes: hashes),
                    face: run.face.name,
                    size: run.size,
                    color: color,
                    stroke: character["stroke"] ?? .off,
                    baselineShift: character["baselineShift"] ?? .off,
                    tracking: .off,
                    highlight: character["highlight"].flatMap { highlight in
                        guard highlight != .off else { return nil }

                        return ResolvedHighlight(
                            color: highlight["color"] ?? .off,
                            padding: highlight["padding"] ?? .off,
                            radius: highlight["radius"] ?? .off,
                            rects: run.highlights
                        )
                    },
                    underline: character["underline"].flatMap { underline in
                        guard underline != .off else { return nil }

                        let written = underline["color"].flatMap { $0 == .off ? nil : $0 }

                        return ResolvedUnderline(
                            color: written ?? color,
                            width: underline["width"] ?? .off,
                            offset: underline["offset"] ?? .off,
                            rects: run.underlines
                        )
                    },
                    glyphs: run.glyphs
                )
            }
        )
    }

    // A label is drawn as set in `color` alone, so its colour is one keyframe and it takes no stroke, baseline shift,
    // highlight or underline.
    init(
        layout: TextLayout,
        color: Color,
        hashes: any FileHashProvider
    ) throws {
        self.init(
            size: layout.size,
            background: layout.background,
            runs: try layout.runs.map { run in
                ResolvedGlyphRun(
                    font: try PinnedFile(path: run.face.file, hashes: hashes),
                    face: run.face.name,
                    size: run.size,
                    color: .track([Keyframe(at: 0, value: .color(color))]),
                    stroke: .off,
                    baselineShift: .off,
                    tracking: .off,
                    highlight: nil,
                    underline: nil,
                    glyphs: run.glyphs
                )
            }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
