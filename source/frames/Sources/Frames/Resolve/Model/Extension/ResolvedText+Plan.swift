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
    // A title takes each run's attributes from the timed value of its text run, and its line height and background
    // from the timed paragraph. An underline leaf no layer gives takes the run's colour. Its units are written where it is
    // animated by unit.
    init(
        plan: TitlePlan,
        hashes: any FileHashProvider
    ) throws {
        let lineHeight = plan.paragraph["lineHeight"] ?? .off
        let background = plan.paragraph["background"].flatMap { background -> ResolvedBackground? in
            guard background != .off else { return nil }

            return ResolvedBackground(
                color: background["color"] ?? .off,
                padding: background["padding"] ?? .off,
                radius: background["radius"] ?? .off
            )
        }

        let runs = try plan.layout.runs.map { run in
            let character = plan.characters[run.source]
            let color = character["color"] ?? .off

            return ResolvedGlyphRun(
                source: run.source,
                font: try PinnedFile(path: run.face.file, hashes: hashes),
                face: run.face.name,
                size: run.size,
                color: color,
                stroke: character["stroke"] ?? .off,
                baselineShift: character["baselineShift"] ?? .off,
                isSideways: run.isSideways,
                horizontalScale: run.horizontalScale,
                staticTracking: run.staticTracking,
                tracking: plan.trackingSteps[run.source],
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

        self.init(
            size: plan.layout.size,
            textBox: plan.layout.textBox,
            width: plan.layout.width,
            background: background,
            writingMode: plan.layout.writingMode,
            direction: plan.layout.direction,
            align: plan.layout.align,
            lineHeight: lineHeight,
            text: plan.layout.text,
            words: plan.layout.words,
            lines: plan.layout.lines,
            units: plan.layout.units.map { units in
                units.map { unit in
                    PlacedUnit(drawing: unit, lines: plan.layout.lines, runs: runs, writingMode: plan.layout.writingMode)
                }
            },
            runs: runs
        )
    }

    // A label is drawn as set in `color` alone, so its colour, line height and background are one keyframe each and it
    // takes no stroke, baseline shift, highlight or underline.
    init(
        layout: TextLayout,
        color: Color,
        hashes: any FileHashProvider
    ) throws {
        let held = { (value: LeafValue) in TimedValue.track([Keyframe(at: 0, value: value)]) }

        self.init(
            size: layout.size,
            textBox: layout.textBox,
            width: layout.width,
            background: layout.background.map { background in
                ResolvedBackground(
                    color: held(.color(background.color)),
                    padding: held(.numbers([background.padding.height, background.padding.width])),
                    radius: held(.numbers(background.radius.values))
                )
            },
            writingMode: layout.writingMode,
            direction: layout.direction,
            align: layout.align,
            lineHeight: held(.number(layout.lineHeight)),
            text: layout.text,
            words: layout.words,
            lines: layout.lines,
            units: nil,
            runs: try layout.runs.map { run in
                ResolvedGlyphRun(
                    source: run.source,
                    font: try PinnedFile(path: run.face.file, hashes: hashes),
                    face: run.face.name,
                    size: run.size,
                    color: held(.color(color)),
                    stroke: .off,
                    baselineShift: .off,
                    isSideways: run.isSideways,
                    horizontalScale: run.horizontalScale,
                    staticTracking: run.staticTracking,
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
