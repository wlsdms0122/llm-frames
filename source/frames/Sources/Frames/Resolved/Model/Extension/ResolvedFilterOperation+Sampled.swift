//
//  ResolvedFilterOperation+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A filter op of a timed filter at one instant, its parameters sampled and clamped to their ranges, nil for a form
// that is no op. A bloom without a colour takes none.
extension ResolvedFilterOperation {
    // MARK: - Property
    // MARK: - Initializer
    init?(sampled: SampledValue) {
        guard case let .form(form, body) = sampled, form.hasPrefix("op:") else { return nil }

        let number = { (key: String) in body[key]?.number ?? 0 }
        let numbers = { (key: String) in body[key]?.numbers ?? [0, 1] }
        switch String(form.dropFirst("op:".count)) {
        case "exposure":
            self = .exposure(ev: number("ev"))

        case "contrast":
            self = .contrast(amount: number("amount"))

        case "saturation":
            self = .saturation(amount: number("amount"))

        case "temperature":
            self = .temperature(kelvin: number("kelvin"))

        case "hue":
            self = .hue(degrees: number("degrees"))

        case "sepia":
            self = .sepia(amount: number("amount"))

        case "levels":
            self = .levels(input: numbers("input"), output: numbers("output"))

        case "lut":
            let file = PinnedFile(path: body["file"]?.name ?? "", sha256: body["sha256"]?.name ?? "")
            self = .lut(file: file, amount: number("amount"))

        case "blur":
            self = .blur(radius: number("radius"))

        case "sharpen":
            self = .sharpen(amount: number("amount"), radius: number("radius"))

        case "bloom":
            self = .bloom(amount: number("amount"), radius: number("radius"), color: body["color"]?.color)

        case "vignette":
            self = .vignette(amount: number("amount"), radius: number("radius"))

        case "pixelate":
            self = .pixelate(size: number("size"))

        case "grain":
            self = .grain(amount: number("amount"), size: number("size"))

        default:
            return nil
        }
    }

    // MARK: - Public
    // MARK: - Private
}
