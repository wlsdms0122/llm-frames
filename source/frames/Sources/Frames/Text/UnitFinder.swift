//
//  UnitFinder.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Splits laid out text into the units a title animated by unit moves, in reading order. Spaces belong to no unit, and
// no unit crosses a line. Units that would share a glyph, as a ligature sets two clusters in one, are one unit.
struct UnitFinder: Sendable {
    // MARK: - Property
    private let segmenter = WordSegmenter()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `lines` are the clusters of each line up to its last visible one, `extents` each line's span down the text's box
    // from its baseline less its largest ascent to its baseline plus its largest descent, and `runs` the glyph runs the
    // clusters name, which hold the highlight and underline pieces.
    func units(
        by unit: TextUnit,
        lines: [[PlacedCluster]],
        extents: [ClosedRange<Double>],
        runs: [GlyphRun]
    ) -> [PlacedUnit] {
        var units: [(line: Int, unit: PlacedUnit)] = []
        for (line, clusters) in lines.enumerated() {
            for group in groups(of: clusters, by: unit) {
                let members = group.map { clusters[$0] }
                guard let first = members.first, let last = members.last else { continue }

                let extent = extents[line]
                units.append((line, PlacedUnit(
                    glyphs: glyphs(of: members),
                    box: Rectangle(
                        x: first.start,
                        y: extent.lowerBound,
                        width: last.end - first.start,
                        height: extent.upperBound - extent.lowerBound
                    ),
                    parts: []
                )))
            }
        }

        var lineOfRun: [Int: Int] = [:]
        for (line, clusters) in lines.enumerated() {
            for cluster in clusters {
                lineOfRun[cluster.glyphs.run] = line
            }
        }
        var parts = units.map { _ in [UnitPart]() }
        for (index, run) in runs.enumerated() {
            guard let line = lineOfRun[index] else { continue }

            let carriers = units.indices.filter { unit in
                units[unit].line == line && units[unit].unit.glyphs.contains { runs[$0.run].source == run.source }
            }
            for (piece, span) in spans(of: run).enumerated() {
                guard !carriers.isEmpty else {
                    // A piece of spaces alone goes with the unit before it, or the first.
                    let before = units.indices.last { units[$0].unit.glyphs.first.map { $0.run < index } ?? false }
                    if let owner = before ?? units.indices.first {
                        parts[owner].append(UnitPart(run: index, piece: piece, span: span))
                    }
                    continue
                }

                for (order, unit) in carriers.enumerated() {
                    let start = order == 0 ? span.lowerBound : units[unit].unit.box.x
                    let end = order == carriers.count - 1 ? span.upperBound : units[carriers[order + 1]].unit.box.x
                    parts[unit].append(UnitPart(run: index, piece: piece, span: start...end))
                }
            }
        }

        return zip(units, parts).map { element, parts in
            PlacedUnit(glyphs: element.unit.glyphs, box: element.unit.box, parts: parts)
        }
    }

    // MARK: - Private
    // The clusters of each unit on a line, by their index, in order.
    private func groups(
        of clusters: [PlacedCluster],
        by unit: TextUnit
    ) -> [[Int]] {
        let visible = clusters.indices.filter { !clusters[$0].character.isWhitespace }
        let groups: [[Int]]
        switch unit {
        case .character:
            groups = visible.map { [$0] }

        case .word:
            groups = words(of: clusters)

        case .line:
            groups = visible.isEmpty ? [] : [visible]
        }

        return groups.reduce(into: [[Int]]()) { merged, group in
            guard
                let first = group.first,
                clusters[first].glyphs.count == 0,
                let previous = merged.last?.last,
                previous == first - 1
            else {
                merged.append(group)
                return
            }

            merged[merged.count - 1] += group
        }
    }

    // A piece between word boundaries that holds a letter, a digit or an ideograph is a word. A piece of punctuation
    // or symbols, with the pieces of them it touches, joins the word it touches, the one before it when it touches
    // two, and is a unit of its own when it touches none.
    private func words(of clusters: [PlacedCluster]) -> [[Int]] {
        let characters = clusters.map(\.character)
        let segments = segmenter.segments(of: characters)
        let isSpace = { (segment: Range<Int>) in characters[segment].allSatisfy(\.isWhitespace) }
        let isWord = { (segment: Range<Int>) in
            characters[segment].contains { character in
                character.unicodeScalars.first.map { scalar in
                    scalar.properties.isAlphabetic
                        || scalar.properties.isIdeographic
                        || scalar.properties.generalCategory == .decimalNumber
                } ?? false
            }
        }

        var groups: [[Int]] = []
        var punctuation: [Int] = []
        var isAfterWord = false
        for segment in segments {
            if isSpace(segment) {
                if !punctuation.isEmpty {
                    groups.append(punctuation)
                    punctuation = []
                }
                isAfterWord = false
            } else if isWord(segment) {
                groups.append(punctuation + Array(segment))
                punctuation = []
                isAfterWord = true
            } else if isAfterWord {
                groups[groups.count - 1] += Array(segment)
            } else {
                punctuation += Array(segment)
            }
        }
        if !punctuation.isEmpty {
            groups.append(punctuation)
        }

        return groups
    }

    // A unit's glyphs, each run of them a range.
    private func glyphs(of clusters: [PlacedCluster]) -> [GlyphRange] {
        clusters.reduce(into: [GlyphRange]()) { ranges, cluster in
            let glyphs = cluster.glyphs
            guard glyphs.count > 0 else { return }

            if let last = ranges.last, last.run == glyphs.run, last.first + last.count == glyphs.first {
                ranges[ranges.count - 1] = GlyphRange(run: last.run, first: last.first, count: last.count + glyphs.count)
            } else {
                ranges.append(glyphs)
            }
        }
    }

    // A run's pieces across the line, its highlight's and its underline's being the same.
    private func spans(of run: GlyphRun) -> [ClosedRange<Double>] {
        let highlights = run.highlights.map { $0.x...($0.x + $0.width) }
        let underlines = run.underlines.map { $0.x...($0.x + $0.width) }

        return highlights.isEmpty ? underlines : highlights
    }
}
