//
//  ProbeReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"probe": "1.0.0", kind, size, duration, fps, alpha, audio}`, the object `probe --json` prints. `size` is
// `[width, height]` and `audio` is `{channels, sampleRate}`, each `null` where the medium has none.
extension ProbeReport {
    // MARK: - Property
    var machineOutput: JSONValue {
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
            JSONMember(key: "audio", value: audio ?? .null)
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
