//
//  DrawnFrame+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// `media`, `mediaTime` and `page`, the members a picture of a media file has in `evaluate` and in `locate`, with
// `locate`'s `point` between `mediaTime` and `page`.
extension DrawnFrame {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func machineOutput(point: JSONMember? = nil) -> [JSONMember] {
        [
            JSONMember(key: "media", value: .string(file)),
            JSONMember(key: "mediaTime", value: .time(mediaTime))
        ]
            + (point.map { [$0] } ?? [])
            + [JSONMember(key: "page", value: page.map { .number(Double($0)) } ?? .null)]
    }

    // MARK: - Private
}
