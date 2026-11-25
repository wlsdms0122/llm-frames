//
//  ReadingOrder.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Puts recognised lines in the order `ocr` lists them: top to bottom by row and left to right within a row. Lines
// whose vertical centres lie within half the shorter one's height of each other are one row, so a row is every line
// such a chain reaches.
struct ReadingOrder: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func sorted(_ lines: [RecognisedLine]) -> [RecognisedLine] {
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

    // MARK: - Private
    private func isSameRow(
        _ first: RecognisedLine,
        _ second: RecognisedLine
    ) -> Bool {
        let distance = abs(first.rectangle.center.y - second.rectangle.center.y)
        return distance <= min(first.rectangle.height, second.rectangle.height) / 2
    }
}
