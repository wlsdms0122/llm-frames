//
//  String+Scalar.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A title's text as its ranges count it, in Unicode scalars.
extension String {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Its text over `range`, a range of its Unicode scalars that lies in them.
    func text(over range: Range<Int>) -> String {
        let scalars = unicodeScalars
        let start = scalars.index(scalars.startIndex, offsetBy: range.lowerBound)
        let end = scalars.index(start, offsetBy: range.count)

        return String(scalars[start..<end])
    }

    // The ranges of its Unicode scalars that `ranges`, ranges of its characters, cover, in order.
    func scalarRanges(of ranges: [Range<Int>]) -> [Range<Int>] {
        let starts = reduce(into: [0]) { starts, character in
            starts.append(starts[starts.count - 1] + character.unicodeScalars.count)
        }

        return ranges.map { starts[$0.lowerBound]..<starts[$0.upperBound] }
    }

    // MARK: - Private
}
