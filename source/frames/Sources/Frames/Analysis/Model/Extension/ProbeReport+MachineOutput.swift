//
//  ProbeReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"probe": "0.1.0", kind, size, duration, fps, alpha, colorSpace, audio, pages}`, the object `probe --json` prints.
// `size` is `[width, height]`, rounded to the millionth, `colorSpace` is `{name, primaries, transfer, matrix, bitDepth,
// hdr}`, `audio` is `{channels, sampleRate}` and `pages` the page count of a PDF, each `null` where the medium has
// none.
extension ProbeReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        let audio = sound.map { sound in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "channels", value: .number(Double(sound.channels))),
                JSONMember(key: "sampleRate", value: .number(sound.sampleRate))
            ]))
        }

        return .object(JSONObject(members: [
            JSONMember(key: "probe", value: .string(FramesVersion.current)),
            JSONMember(key: "kind", value: kind.map(JSONValue.string) ?? .null),
            JSONMember(key: "size", value: size.map { .array([.measure($0.width), .measure($0.height)]) } ?? .null),
            JSONMember(key: "duration", value: duration.map(JSONValue.time) ?? .null),
            JSONMember(key: "fps", value: fps.map(JSONValue.number) ?? .null),
            JSONMember(key: "alpha", value: hasAlpha.map(JSONValue.bool) ?? .null),
            JSONMember(key: "colorSpace", value: colorSpace.map(Self.written) ?? .null),
            JSONMember(key: "audio", value: audio ?? .null),
            JSONMember(key: "pages", value: pageCount.map { .number(Double($0)) } ?? .null)
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private static func written(_ colorSpace: ProbedColorSpace) -> JSONValue {
        let wholeNumber = { (value: Int?) in value.map { JSONValue.number(Double($0)) } ?? .null }

        return .object(JSONObject(members: [
            JSONMember(key: "name", value: colorSpace.name.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "primaries", value: wholeNumber(colorSpace.primaries)),
            JSONMember(key: "transfer", value: wholeNumber(colorSpace.transfer)),
            JSONMember(key: "matrix", value: wholeNumber(colorSpace.matrix)),
            JSONMember(key: "bitDepth", value: wholeNumber(colorSpace.bitDepth)),
            JSONMember(key: "hdr", value: .bool(colorSpace.isHighDynamicRange))
        ]))
    }
}
