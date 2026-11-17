//
//  TrackReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"track": "1.0.0", frames}`, the object `track` always prints, each frame `{time, rect}` with its rectangle
// `[x, y, w, h]` in media pixels.
extension TrackReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "track", value: .string(FramesVersion.current)),
            JSONMember(key: "frames", value: .array(frames.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ frame: TrackedFrame) -> JSONValue {
        let rectangle = frame.rectangle

        return .object(JSONObject(members: [
            JSONMember(key: "time", value: .time(frame.time)),
            JSONMember(
                key: "rect",
                value: .array([rectangle.x, rectangle.y, rectangle.width, rectangle.height].map(JSONValue.measure))
            )
        ]))
    }
}
