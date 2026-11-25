//
//  TrackReport+TrackData.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

@testable import Frames

// What `track` prints without its first key, the version, which is the track data a clip's `track` takes (FRAMES-12
// Track data).
extension TrackReport {
    // MARK: - Property
    var trackData: String {
        guard case let .object(object) = machineOutput else { return "" }

        return JSONWriter().write(.object(JSONObject(members: object.members.filter { $0.key != "track" })))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
