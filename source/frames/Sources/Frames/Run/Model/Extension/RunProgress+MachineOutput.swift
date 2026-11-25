//
//  RunProgress+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// `{"progress": "0.1.0", frame, frames, seconds}`, a line of `render --progress json`, and `frame <k>/<n>`, a line of
// `--progress text` (FRAMES-23 Runs).
extension RunProgress {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "progress", value: .string(FramesVersion.current)),
            JSONMember(key: "frame", value: .number(Double(frame))),
            JSONMember(key: "frames", value: .number(Double(frames))),
            JSONMember(key: "seconds", value: .time(seconds))
        ]))
    }

    package var text: String {
        "frame \(frame)/\(frames)"
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
