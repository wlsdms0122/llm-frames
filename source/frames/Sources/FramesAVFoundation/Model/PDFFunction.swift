//
//  PDFFunction.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// A PDF function (ISO 32000-1 7.10) as a tint transform takes a colour's tints to its alternate space's components: a
// sampled function (type 0) of linear interpolation between its samples, an exponential interpolation function (type
// 2), a stitching function (type 3) of functions of one input, or a PostScript calculator function (type 4). Each input
// is clipped to `domain` and each output to `range` where the function writes one.
indirect enum PDFFunction: Equatable, Sendable {
    case sampled(
        domain: [Double],
        range: [Double],
        size: [Int],
        encode: [Double],
        decode: [Double],
        maximumSample: Double,
        samples: [Double]
    )
    case exponential(domain: [Double], range: [Double]?, start: [Double], end: [Double], exponent: Double)
    case stitching(domain: [Double], range: [Double]?, functions: [PDFFunction], bounds: [Double], encode: [Double])
    case calculator(domain: [Double], range: [Double], program: PostScriptCalculator)

    // MARK: - Property
    private static let bitsPerSampleWritten = [1, 2, 4, 8, 12, 16, 24, 32]

    // MARK: - Initializer
    // The function `value` writes, nil where it is not one this reader evaluates: a sampled function of cubic spline
    // interpolation (`Order` 3) is not.
    init?(_ value: PDFValue) {
        guard let entries = value.dictionaryValue, let type = entries["FunctionType"]?.number else { return nil }
        let domain = entries["Domain"]?.numbers ?? []
        let range = entries["Range"]?.numbers
        guard domain.count >= 2, domain.count % 2 == 0 else { return nil }

        switch Int(type) {
        case 0:
            guard
                case let .stream(_, data) = value,
                let range,
                let sampled = Self.sampled(entries, domain: domain, range: range, data: data)
            else {
                return nil
            }
            self = sampled

        case 2:
            guard domain.count == 2, let exponent = entries["N"]?.number else { return nil }
            self = .exponential(
                domain: domain,
                range: range,
                start: entries["C0"]?.numbers ?? [0],
                end: entries["C1"]?.numbers ?? [1],
                exponent: exponent
            )

        case 3:
            guard
                domain.count == 2,
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

        case 4:
            guard
                case let .stream(_, data) = value,
                let range,
                range.count >= 2,
                range.count % 2 == 0,
                let text = String(data: data, encoding: .isoLatin1),
                let program = PostScriptCalculator(text)
            else {
                return nil
            }
            self = .calculator(domain: domain, range: range, program: program)

        default:
            return nil
        }
    }

    // MARK: - Public
    // The outputs for `inputs`, nil where a PostScript calculator function stops on an error.
    func callAsFunction(_ inputs: [Double]) -> [Double]? {
        switch self {
        case let .sampled(domain, range, size, encode, decode, maximumSample, samples):
            let positions = size.indices.map { index in
                let x = Self.clipped(Self.input(inputs, index), to: domain, at: index)
                let e = Self.interpolated(
                    x,
                    from: domain[index * 2],
                    domain[index * 2 + 1],
                    to: encode[index * 2],
                    encode[index * 2 + 1]
                )

                return min(max(e, 0), Double(size[index] - 1))
            }
            let interpolated = Self.interpolatedSamples(at: positions, size: size, samples: samples, outputs: range.count / 2)
            let outputs = interpolated.enumerated().map { index, sample in
                Self.interpolated(sample, from: 0, maximumSample, to: decode[index * 2], decode[index * 2 + 1])
            }

            return Self.clipped(outputs, to: range)

        case let .exponential(domain, range, start, end, exponent):
            let x = Self.clipped(Self.input(inputs, 0), to: domain, at: 0)
            let outputs = zip(start, end).map { start, end in start + pow(x, exponent) * (end - start) }

            return Self.clipped(outputs, to: range)

        case let .stitching(domain, range, functions, bounds, encode):
            let x = Self.clipped(Self.input(inputs, 0), to: domain, at: 0)
            let index = bounds.firstIndex { x < $0 } ?? bounds.count
            let lower = index == 0 ? domain[0] : bounds[index - 1]
            let upper = index == bounds.count ? domain[1] : bounds[index]
            let encoded = upper == lower
                ? encode[index * 2]
                : Self.interpolated(x, from: lower, upper, to: encode[index * 2], encode[index * 2 + 1])

            return functions[index]([encoded]).map { Self.clipped($0, to: range) }

        case let .calculator(domain, range, program):
            let clipped = (0..<domain.count / 2).map { index in
                Self.clipped(Self.input(inputs, index), to: domain, at: index)
            }
            guard let outputs = program.run(clipped), outputs.count == range.count / 2 else { return nil }

            return Self.clipped(outputs, to: range)
        }
    }

    // MARK: - Private
    // A sampled function's entries and samples: each sample of `BitsPerSample` bits, the first input varying fastest,
    // with no padding between samples.
    private static func sampled(
        _ entries: [String: PDFValue],
        domain: [Double],
        range: [Double],
        data: Data
    ) -> PDFFunction? {
        let inputCount = domain.count / 2
        let outputCount = range.count / 2
        guard
            range.count >= 2,
            range.count % 2 == 0,
            let size = entries["Size"]?.numbers?.map(Int.init),
            size.count == inputCount,
            size.allSatisfy({ $0 >= 1 }),
            let bitsPerSample = entries["BitsPerSample"]?.number.map(Int.init),
            bitsPerSampleWritten.contains(bitsPerSample),
            (entries["Order"]?.number ?? 1) == 1
        else {
            return nil
        }
        let encode = entries["Encode"]?.numbers ?? size.flatMap { [0, Double($0 - 1)] }
        let decode = entries["Decode"]?.numbers ?? range
        let sampleCount = size.reduce(1, *) * outputCount
        guard
            encode.count == inputCount * 2,
            decode.count == outputCount * 2,
            data.count * 8 >= sampleCount * bitsPerSample
        else {
            return nil
        }

        let bytes = [UInt8](data)
        let samples = (0..<sampleCount).map { index in
            var sample: UInt64 = 0
            for bit in index * bitsPerSample..<(index + 1) * bitsPerSample {
                sample = sample << 1 | UInt64(bytes[bit / 8] >> (7 - bit % 8) & 1)
            }

            return Double(sample)
        }

        return .sampled(
            domain: domain,
            range: range,
            size: size,
            encode: encode,
            decode: decode,
            maximumSample: Double((UInt64(1) << bitsPerSample) - 1),
            samples: samples
        )
    }

    // The samples at `positions` in the sample grid, by linear interpolation along each input between the samples
    // either side.
    private static func interpolatedSamples(
        at positions: [Double],
        size: [Int],
        samples: [Double],
        outputs: Int
    ) -> [Double] {
        let lower = zip(positions, size).map { position, size in min(Int(position.rounded(.down)), size - 1) }
        let fractions = zip(positions, lower).map { $0 - Double($1) }
        var result = [Double](repeating: 0, count: outputs)
        for corner in 0..<(1 << positions.count) {
            var weight = 1.0
            var offset = 0
            var stride = 1
            for index in positions.indices {
                let isUpper = corner >> index & 1 == 1
                let coordinate = min(lower[index] + (isUpper ? 1 : 0), size[index] - 1)
                weight *= isUpper ? fractions[index] : 1 - fractions[index]
                offset += coordinate * stride
                stride *= size[index]
            }
            guard weight > 0 else { continue }
            for output in 0..<outputs {
                result[output] += weight * samples[offset * outputs + output]
            }
        }

        return result
    }

    private static func input(
        _ inputs: [Double],
        _ index: Int
    ) -> Double {
        inputs.indices.contains(index) ? inputs[index] : 0
    }

    private static func interpolated(
        _ x: Double,
        from lower: Double,
        _ upper: Double,
        to start: Double,
        _ end: Double
    ) -> Double {
        upper == lower ? start : start + (x - lower) * (end - start) / (upper - lower)
    }

    private static func clipped(
        _ value: Double,
        to interval: [Double],
        at index: Int
    ) -> Double {
        guard interval.count >= index * 2 + 2 else { return value }

        return min(max(value, interval[index * 2]), interval[index * 2 + 1])
    }

    private static func clipped(
        _ values: [Double],
        to range: [Double]?
    ) -> [Double] {
        guard let range else { return values }

        return values.indices.map { clipped(values[$0], to: range, at: $0) }
    }
}
