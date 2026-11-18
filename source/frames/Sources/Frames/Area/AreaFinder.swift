//
//  AreaFinder.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Finds an area in a picture at one media time: a rectangle as written, or text through the OCR provider in the
// recognition languages, nil where the provider detects them. An area
// found by text grows by its padding, in the picture's pixels. Every area is cut to the picture, and one wholly
// outside it stops.
struct AreaFinder: Sendable {
    // MARK: - Property
    private let ocr: any OCRProvider
    private let languages: [LanguageTag]?
    private let order = ReadingOrder()

    // MARK: - Initializer
    init(
        ocr: any OCRProvider,
        languages: [LanguageTag]? = nil
    ) {
        self.ocr = ocr
        self.languages = languages
    }

    // MARK: - Public
    func area(
        _ form: AreaForm,
        in picture: Picture,
        atMediaTime time: Double,
        place: Place,
        kind: String
    ) throws -> FoundArea {
        switch form {
        case let .rectangle(rectangle):
            let cut = try cut(rectangle, to: picture, place: place, kind: kind)
            return FoundArea(rectangle: cut, target: cut, mediaTime: time, lines: [])

        case let .text(text, nth, padding):
            let lines = try recognisedLines(in: picture, atMediaTime: time, place: place, kind: kind)
            let line = try line(text, nth: nth, among: lines, picture: picture, time: time, place: place, kind: kind)
            return try textArea([line], in: picture, atMediaTime: time, padding: padding, place: place, kind: kind)

        case let .range(from, fromNth, to, toNth, padding):
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

            return try textArea(
                ends + between,
                in: picture,
                atMediaTime: time,
                padding: padding,
                place: place,
                kind: kind
            )
        }
    }

    // MARK: - Private
    private func recognisedLines(
        in picture: Picture,
        atMediaTime time: Double,
        place: Place,
        kind: String
    ) throws -> [RecognisedLine] {
        switch picture.source {
        case let .mediaFile(file):
            return order.sorted(try ocr.lines(in: file, atMediaTime: time, languages: languages))

        case .document:
            throw AreaError.textInDocument(place: place, kind: kind, picture: picture.name)

        case .space:
            throw AreaError.textInSpace(place: place, kind: kind, parent: picture.name)
        }
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
            nth: nth,
            matchCount: matches.count
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

    private func cut(
        _ rectangle: Rectangle,
        to picture: Picture,
        place: Place,
        kind: String
    ) throws -> Rectangle {
        // A space has no edges to cut at.
        guard picture.source != .space else { return rectangle }
        guard let cut = rectangle.intersection(picture.bounds) else {
            throw AreaError.outsidePicture(place: place, kind: kind, rectangle: rectangle, size: picture.size)
        }

        return cut
    }

    private func withoutWhitespace(_ text: String) -> String {
        String(text.unicodeScalars.filter { !$0.properties.isWhitespace }.map(Character.init))
    }
}
