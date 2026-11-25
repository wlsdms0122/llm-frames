//
//  TrackReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"track": "0.1.0", time, frames}`, the object `track` always prints: the media time of `--at`, and each frame
// `{time, quad}`, a quad as four points `[x, y]` in media pixels. Without its first key it is the track data a clip's
// `track` takes.
extension TrackReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "track", value: .string(FramesVersion.current)),
            JSONMember(key: "time", value: .time(time)),
            JSONMember(key: "frames", value: .array(frames.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ frame: TrackedFrame) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "time", value: .time(frame.time)),
            JSONMember(key: "quad", value: quad(frame.quad))
        ]))
    }

    private func quad(_ quad: Quad) -> JSONValue {
        .array(quad.corners.map { corner in .array([corner.x, corner.y].map(JSONValue.measure)) })
    }
}
