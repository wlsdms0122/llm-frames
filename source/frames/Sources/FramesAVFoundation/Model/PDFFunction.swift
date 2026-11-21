//
//  PDFFunction.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// A PDF function of one input (ISO 32000-1 7.10) as a tint transform takes a tint to its alternate space's components:
// an exponential interpolation function (type 2), or a stitching function (type 3) of such functions. Its input is
// clipped to `domain` and each output to `range` where the function writes one.
indirect enum PDFFunction: Equatable, Sendable {
    case exponential(domain: [Double], range: [Double]?, start: [Double], end: [Double], exponent: Double)
    case stitching(domain: [Double], range: [Double]?, functions: [PDFFunction], bounds: [Double], encode: [Double])

    // MARK: - Property
    // MARK: - Initializer
    // The function `value` writes, nil for a function type this reader does not evaluate.
    init?(_ value: PDFValue) {
        guard let entries = value.dictionaryValue, let type = entries["FunctionType"]?.number else { return nil }
        let domain = entries["Domain"]?.numbers ?? [0, 1]
        let range = entries["Range"]?.numbers
        guard domain.count >= 2 else { return nil }

        switch Int(type) {
        case 2:
            guard let exponent = entries["N"]?.number else { return nil }
            self = .exponential(
                domain: domain,
                range: range,
                start: entries["C0"]?.numbers ?? [0],
                end: entries["C1"]?.numbers ?? [1],
                exponent: exponent
            )

        case 3:
            guard
                let written = entries["Functions"]?.arrayValue,
                let bounds = entries["Bounds"]?.numbers,
                let encode = entries["Encode"]?.numbers
            else {
                return nil
            }
            let functions = written.compactMap(PDFFunction.init)
            guard
                functions.count == written.count,
                bounds.count == functions.count - 1,
                encode.count == functions.count * 2
            else {
                return nil
            }
            self = .stitching(domain: domain, range: range, functions: functions, bounds: bounds, encode: encode)

        default:
            return nil
        }
    }

    // MARK: - Public
    func callAsFunction(_ input: Double) -> [Double] {
        switch self {
        case let .exponential(domain, range, start, end, exponent):
            let x = Self.clipped(input, to: domain)
            let outputs = zip(start, end).map { start, end in start + pow(x, exponent) * (end - start) }

            return Self.clipped(outputs, to: range)

        case let .stitching(domain, range, functions, bounds, encode):
            let x = Self.clipped(input, to: domain)
            let index = bounds.firstIndex { x < $0 } ?? bounds.count
            let lower = index == 0 ? domain[0] : bounds[index - 1]
            let upper = index == bounds.count ? domain[1] : bounds[index]
            let (encodedLower, encodedUpper) = (encode[index * 2], encode[index * 2 + 1])
            let encoded = upper == lower
                ? encodedLower
                : encodedLower + (x - lower) * (encodedUpper - encodedLower) / (upper - lower)

            return Self.clipped(functions[index](encoded), to: range)
        }
    }

    // MARK: - Private
    private static func clipped(
        _ value: Double,
        to interval: [Double]
    ) -> Double {
        min(max(value, interval[0]), interval[1])
    }

    private static func clipped(
        _ values: [Double],
        to range: [Double]?
    ) -> [Double] {
        guard let range else { return values }

        return values.enumerated().map { index, value in
            range.count >= index * 2 + 2 ? clipped(value, to: [range[index * 2], range[index * 2 + 1]]) : value
        }
    }
}
