//
//  OCRReport+Text.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The text `ocr` prints for people: `size WxH`, then `[x, y, w, h]  text` for each line, its rectangle rounded to
// whole pixels. When more than one frame is read, as over a range, each goes under a line with its media time. It is
// not part of the contract.
extension OCRReport {
    // MARK: - Property
    package var text: String {
        let lines = frames.count == 1
            ? frames[0].lines.map(line)
            : frames.flatMap { frame in ["time \(JSONValue.time(frame.time).written)"] + frame.lines.map(line) }

        return (["size \(number(size.width))x\(number(size.height))"] + lines).joined(separator: "\n")
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func line(_ line: RecognisedLine) -> String {
        let rectangle = line.rectangle
        let numbers = [rectangle.x, rectangle.y, rectangle.width, rectangle.height].map { number($0.rounded()) }

        return "[\(numbers.joined(separator: ", "))]  \(line.text)"
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}
