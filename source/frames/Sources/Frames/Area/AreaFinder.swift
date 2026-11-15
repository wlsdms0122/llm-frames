//
//  AreaFinder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Finds an area in a picture at one media time: a rectangle as written, or text through the OCR provider. An area
// found by text grows by `padding`, in the picture's pixels, before a band widens it. Every area is cut to the
// picture, and one wholly outside it stops.
struct AreaFinder: Sendable {
    // MARK: - Property
    private let ocr: any OCRProvider

    // MARK: - Initializer
    init(ocr: any OCRProvider) {
        self.ocr = ocr
    }

    // MARK: - Public
    func area(
        _ form: AreaForm,
        in picture: Picture,
        atMediaTime time: Double,
        padding: Double,
        place: Place,
        kind: String
    ) throws -> FoundArea {
        switch form {
        case let .band(inner):
            let found = try area(inner, in: picture, atMediaTime: time, padding: padding, place: place, kind: kind)
            return FoundArea(
                rectangle: Rectangle(x: 0, y: found.rectangle.y, width: picture.size.width, height: found.rectangle.height),
                target: found.target,
                isBand: true,
                mediaTime: time,
                lines: found.lines
            )

        case let .rectangle(rectangle):
            let cut = try cut(rectangle, to: picture, place: place, kind: kind)
            return FoundArea(rectangle: cut, target: cut, isBand: false, mediaTime: time, lines: [])

        case let .text(text, nth):
            let lines = try recognisedLines(in: picture, atMediaTime: time, place: place, kind: kind)
            let line = try line(text, nth: nth, among: lines, picture: picture, time: time, place: place, kind: kind)
            return try textArea([line], in: picture, atMediaTime: time, padding: padding, place: place, kind: kind)

        case let .range(from, fromNth, to, toNth):
            let lines = try recognisedLines(in: picture, atMediaTime: time, place: place, kind: kind)
            let ends = [
                try line(from, nth: fromNth, among: lines, picture: picture, time: time, place: place, kind: kind),
                try line(to, nth: toNth, among: lines, picture: picture, time: time, place: place, kind: kind)
            ]
            let top = ends.map(\.rectangle.y).reduce(.infinity, min)
            let bottom = ends.map(\.rectangle.maxY).reduce(-.infinity, max)
            let between = lines.filter { line in
                !ends.contains(line) && (top...bottom).contains(line.rectangle.center.y)
            }

            return try textArea(ends + between, in: picture, atMediaTime: time, padding: padding, place: place, kind: kind)
        }
    }

    // MARK: - Private
    private func recognisedLines(
        in picture: Picture,
        atMediaTime time: Double,
        place: Place,
        kind: String
    ) throws -> [RecognisedLine] {
        guard let file = picture.file else {
            throw AreaError.textInDrawnPicture(place: place, kind: kind, picture: picture.name)
        }

        return ordered(try ocr.lines(in: file, atMediaTime: time))
    }

    // The rectangle around the lines, grown by the padding. The target is the same rectangle before padding.
    private func textArea(
        _ lines: [RecognisedLine],
        in picture: Picture,
        atMediaTime time: Double,
        padding: Double,
        place: Place,
        kind: String
    ) throws -> FoundArea {
        let rectangle = lines.dropFirst().reduce(lines[0].rectangle) { $0.union($1.rectangle) }

        return FoundArea(
            rectangle: try cut(rectangle.grown(by: padding), to: picture, place: place, kind: kind),
            target: try cut(rectangle, to: picture, place: place, kind: kind),
            isBand: false,
            mediaTime: time,
            lines: lines
        )
    }

    private func line(
        _ text: String,
        nth: Int?,
        among lines: [RecognisedLine],
        picture: Picture,
        time: Double,
        place: Place,
        kind: String
    ) throws -> RecognisedLine {
        let wanted = withoutWhitespace(text)
        let matches = lines.filter { withoutWhitespace($0.text).contains(wanted) }
        let noMatch = AreaError.noMatch(
            place: place,
            kind: kind,
            picture: picture.name,
            mediaTime: time,
            text: text,
            nth: nth
        )

        guard let nth else {
            guard let match = matches.first else { throw noMatch }
            guard matches.count == 1 else {
                throw AreaError.ambiguousText(place: place, kind: kind, text: text, matches: matches)
            }

            return match
        }
        guard matches.indices.contains(nth) else { throw noMatch }

        return matches[nth]
    }

    // Top to bottom by row and left to right within a row. Lines whose vertical centres lie within half the shorter
    // one's height of each other are one row, so a row is every line such a chain reaches.
    private func ordered(_ lines: [RecognisedLine]) -> [RecognisedLine] {
        let byCenter = lines.enumerated().sorted { left, right in
            left.element.rectangle.center.y == right.element.rectangle.center.y
                ? left.offset < right.offset
                : left.element.rectangle.center.y < right.element.rectangle.center.y
        }
        let rows = byCenter.map(\.element).reduce(into: [[RecognisedLine]]()) { rows, line in
            guard let last = rows.last, last.contains(where: { isSameRow($0, line) }) else {
                rows.append([line])
                return
            }

            rows[rows.count - 1].append(line)
        }

        return rows.flatMap { row in row.sorted { $0.rectangle.x < $1.rectangle.x } }
    }

    private func isSameRow(
        _ first: RecognisedLine,
        _ second: RecognisedLine
    ) -> Bool {
        let distance = abs(first.rectangle.center.y - second.rectangle.center.y)
        return distance <= min(first.rectangle.height, second.rectangle.height) / 2
    }

    private func cut(
        _ rectangle: Rectangle,
        to picture: Picture,
        place: Place,
        kind: String
    ) throws -> Rectangle {
        guard let cut = rectangle.intersection(picture.bounds) else {
            throw AreaError.outsidePicture(place: place, kind: kind, rectangle: rectangle, size: picture.size)
        }

        return cut
    }

    private func withoutWhitespace(_ text: String) -> String {
        String(text.unicodeScalars.filter { !$0.properties.isWhitespace }.map(Character.init))
    }
}
