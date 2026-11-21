//
//  UnitFinder.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Splits laid out text into the units a title animated by unit moves, in reading order. Spaces belong to no unit, and
// no unit crosses a line. Units that would share a glyph, as a ligature sets two clusters in one, are one unit.
struct UnitFinder: Sendable {
    // A character of a line: its cluster, its text, and its glyph box's span across the line.
    typealias Cluster = (cluster: PlacedCluster, character: Character, span: ClosedRange<Double>)

    // MARK: - Property
    private let segmenter = WordSegmenter()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `lines` are the characters of each line, `extents` each line's span down the text's box from its baseline less
    // its largest ascent to its baseline plus its largest descent, and `runs` the text's glyph runs, which hold the
    // highlight and underline pieces. A run's glyphs may lie in no character, as the spaces that hang past a line's
    // end do, so a run's line is its own.
    func units(
        by unit: TextUnit,
        lines: [[Cluster]],
        extents: [ClosedRange<Double>],
        runs: [GlyphRun]
    ) -> [PlacedUnit] {
        var units: [(line: Int, unit: PlacedUnit)] = []
        for (line, clusters) in lines.enumerated() {
            for group in groups(of: clusters, by: unit) {
                let members = group.map { clusters[$0] }
                guard let first = members.first, let last = members.last else { continue }

                let extent = extents[line]
                let box = Rectangle(
                    x: first.span.lowerBound,
                    y: extent.lowerBound,
                    width: last.span.upperBound - first.span.lowerBound,
                    height: extent.upperBound - extent.lowerBound
                )
                units.append((line, PlacedUnit(glyphs: glyphs(of: members), glyphBox: box, box: box, parts: [])))
            }
        }

        var parts = units.map { _ in [UnitPart]() }
        for (index, run) in runs.enumerated() {
            let onLine = units.indices.filter { units[$0].line == run.line }
            let carriers = onLine.filter { unit in
                units[unit].unit.glyphs.contains { runs[$0.run].source == run.source }
            }
            for (piece, span) in spans(of: run).enumerated() {
                guard !carriers.isEmpty else {
                    if let owner = owner(ofSpacesIn: index, of: run, onLine: onLine, units: units) {
                        parts[owner].append(UnitPart(run: index, piece: piece, span: span))
                    }
                    continue
                }

                for (order, unit) in carriers.enumerated() {
                    let start = order == 0 ? span.lowerBound : units[unit].unit.glyphBox.x
                    let end = order == carriers.count - 1 ? span.upperBound : units[carriers[order + 1]].unit.glyphBox.x
                    parts[unit].append(UnitPart(run: index, piece: piece, span: start...end))
                }
            }
        }

        return zip(units, parts).map { element, parts in
            PlacedUnit(glyphs: element.unit.glyphs, glyphBox: element.unit.glyphBox, box: element.unit.box, parts: parts)
        }
    }

    // MARK: - Private
    // A piece of spaces alone goes with the unit before it on its line, or the line's first, so its part stays on its
    // line. On a line with no unit it goes with the unit before it in reading order, or the title's first, so every
    // piece of a title with a unit is drawn by one.
    private func owner(
        ofSpacesIn index: Int,
        of run: GlyphRun,
        onLine: [Int],
        units: [(line: Int, unit: PlacedUnit)]
    ) -> Int? {
        let before = onLine.last { units[$0].unit.glyphs.first.map { $0.run < index } ?? false }
        let earlier = units.indices.last { units[$0].line < run.line }

        return before ?? onLine.first ?? earlier ?? units.indices.first
    }

    // The clusters of each unit on a line, by their index, in order.
    private func groups(
        of clusters: [Cluster],
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
                clusters[first].cluster.glyphs.count == 0,
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
    private func words(of clusters: [Cluster]) -> [[Int]] {
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
    private func glyphs(of clusters: [Cluster]) -> [GlyphRange] {
        clusters.reduce(into: [GlyphRange]()) { ranges, cluster in
            let glyphs = cluster.cluster.glyphs
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
