//
//  TrackReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"track": "1.0.0", time, target, frames}`, the object `track` always prints: the media time of `--at`, the target's
// quad there, and each frame `{time, quad, motion}`, a quad as four points `[x, y]` in media pixels and the motion as
// the matrix `[a, b, c, d, tx, ty]`, as the resolved document writes them.
extension TrackReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "track", value: .string(FramesVersion.current)),
            JSONMember(key: "time", value: .time(track.mediaTime)),
            JSONMember(key: "target", value: quad(track.target)),
            JSONMember(key: "frames", value: .array(track.samples.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ sample: TrackSample) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "time", value: .time(sample.time)),
            JSONMember(key: "quad", value: quad(sample.quad)),
            JSONMember(key: "motion", value: .array(sample.motion.transform.matrix.map(JSONValue.measure)))
        ]))
    }

    private func quad(_ quad: Quad) -> JSONValue {
        .array(quad.corners.map { corner in .array([corner.x, corner.y].map(JSONValue.measure)) })
    }
}
