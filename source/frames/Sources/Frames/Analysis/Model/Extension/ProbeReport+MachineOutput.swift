//
//  ProbeReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"probe": "1.0.0", kind, size, duration, fps, alpha, colorSpace, audio}`, the object `probe --json` prints. `size`
// is `[width, height]`, `colorSpace` is `{name, primaries, transfer, matrix, bitDepth, hdr}` and `audio` is
// `{channels, sampleRate}`, each `null` where the medium has none.
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
            JSONMember(key: "kind", value: .string(kind)),
            JSONMember(key: "size", value: size.map { .array([.number($0.width), .number($0.height)]) } ?? .null),
            JSONMember(key: "duration", value: duration.map(JSONValue.time) ?? .null),
            JSONMember(key: "fps", value: fps.map(JSONValue.number) ?? .null),
            JSONMember(key: "alpha", value: .bool(hasAlpha)),
            JSONMember(key: "colorSpace", value: colorSpace.map(Self.written) ?? .null),
            JSONMember(key: "audio", value: audio ?? .null)
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private static func written(_ colorSpace: ProbedColorSpace) -> JSONValue {
        let codePoint = { (value: Int?) in value.map { JSONValue.number(Double($0)) } ?? .null }

        return .object(JSONObject(members: [
            JSONMember(key: "name", value: colorSpace.name.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "primaries", value: codePoint(colorSpace.primaries)),
            JSONMember(key: "transfer", value: codePoint(colorSpace.transfer)),
            JSONMember(key: "matrix", value: codePoint(colorSpace.matrix)),
            JSONMember(key: "bitDepth", value: .number(Double(colorSpace.bitDepth))),
            JSONMember(key: "hdr", value: .bool(colorSpace.isHighDynamicRange))
        ]))
    }
}
