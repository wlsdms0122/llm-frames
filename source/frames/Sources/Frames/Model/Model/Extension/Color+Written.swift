//
//  Color+Written.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// The forms a colour value is written in (FRAMES-26): a hex colour, which is sRGB, or `color(<space> c1 c2 c3 / a)`
// in `srgb`, `srgb-linear`, `display-p3` or `rec2020`; and `color(srgb r g b / a)`, the one form the resolved document
// and display lists write, each number in the number form of FRAMES-19.
extension Color {
    // MARK: - Property
    package var resolvedForm: String {
        let writer = JSONWriter()
        let numbers = [red, green, blue].map(writer.number).joined(separator: " ")

        return "color(srgb \(numbers) / \(writer.number(alpha)))"
    }

    // MARK: - Initializer
    // A hex colour or a `color()` value, nil for a string that does not match the grammar, a component that is not
    // finite or an alpha outside 0 to 1.
    package init?(parsing written: String) {
        if written.hasPrefix("#") {
            guard let color = Self.hex(written) else { return nil }

            self = color
        } else {
            guard let color = Self.function(written) else { return nil }

            self = color
        }
    }

    // `written` is a hex colour or a `color()` value, as the key tables let it through.
    package init(written: String) {
        self = Color(parsing: written) ?? .black
    }

    // `color(srgb r g b / a)` with one space between the parts and around `/`, nil for any other form.
    package init?(resolvedForm: String) {
        guard resolvedForm.hasPrefix("color(srgb "), resolvedForm.hasSuffix(")") else { return nil }

        let parts = resolvedForm.dropFirst("color(srgb ".count).dropLast().split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 5, parts[3] == "/" else { return nil }

        let numbers = [parts[0], parts[1], parts[2], parts[4]].compactMap(Self.number)
        guard numbers.count == 4, (0...1).contains(numbers[3]) else { return nil }

        self.init(red: numbers[0], green: numbers[1], blue: numbers[2], alpha: numbers[3])
    }

    // MARK: - Public
    // MARK: - Private
    private static func hex(_ written: String) -> Color? {
        let digits = Array(written.dropFirst())
        guard [6, 8].contains(digits.count), digits.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }

        let values = stride(from: 0, to: digits.count, by: 2).compactMap { index in
            Int(String(digits[index..<index + 2]), radix: 16).map { Double($0) / 255 }
        }

        return Color(red: values[0], green: values[1], blue: values[2], alpha: values.count == 4 ? values[3] : 1)
    }

    // `color(` *SP space 1*SP number 1*SP number 1*SP number [ *SP "/" *SP number ] *SP `)`.
    private static func function(_ written: String) -> Color? {
        guard written.hasPrefix("color("), written.hasSuffix(")") else { return nil }

        let body = written.dropFirst("color(".count).dropLast()
        let halves = body.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let components = halves[0].split(separator: " ")
        let values = components.dropFirst().compactMap(number)
        guard components.count == 4, values.count == 3, let space = components.first else { return nil }

        var alpha = 1.0
        if halves.count == 2 {
            guard let written = number(halves[1].trimmingSpaces), (0...1).contains(written) else { return nil }

            alpha = written
        }

        let value = RGB(red: values[0], green: values[1], blue: values[2])
        switch space {
        case "srgb":
            return Color(encoded: value, alpha: alpha)

        case "srgb-linear":
            return Color(linear: value, alpha: alpha)

        case "display-p3":
            return Color(encoded: ColorConversion(space: .displayP3).working(value), alpha: alpha)

        case "rec2020":
            return Color(encoded: ColorConversion(space: .rec2020).working(value), alpha: alpha)

        default:
            return nil
        }
    }

    // `[ "+" | "-" ] ( 1*DIGIT [ "." 1*DIGIT ] | "." 1*DIGIT ) [ ( "e" | "E" ) [ "+" | "-" ] 1*DIGIT ]`, finite.
    private static func number(_ written: Substring) -> Double? {
        var rest = written[...]
        if let sign = rest.first, sign == "+" || sign == "-" {
            rest = rest.dropFirst()
        }

        let whole = rest.prefix(while: \.isASCIIDigit)
        rest = rest.dropFirst(whole.count)
        if rest.first == "." {
            rest = rest.dropFirst()
            let fraction = rest.prefix(while: \.isASCIIDigit)
            guard !fraction.isEmpty else { return nil }

            rest = rest.dropFirst(fraction.count)
        } else {
            guard !whole.isEmpty else { return nil }
        }
        if let marker = rest.first, marker == "e" || marker == "E" {
            rest = rest.dropFirst()
            if let sign = rest.first, sign == "+" || sign == "-" {
                rest = rest.dropFirst()
            }
            let exponent = rest.prefix(while: \.isASCIIDigit)
            guard !exponent.isEmpty else { return nil }

            rest = rest.dropFirst(exponent.count)
        }
        guard rest.isEmpty, let value = Double(String(written)), value.isFinite else { return nil }

        return value
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}

private extension Substring {
    var trimmingSpaces: Substring {
        var trimmed = drop { $0 == " " }
        while trimmed.last == " " {
            trimmed = trimmed.dropLast()
        }

        return trimmed
    }
}
