//
//  OCRReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"ocr": "1.0.0", size, frames}`, the object `ocr --json` prints: `size` as `[width, height]`, each frame
// `{time, lines}` and each line `{text, rect}`, its rectangle `[x, y, w, h]` in media pixels.
extension OCRReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "ocr", value: .string(FramesVersion.current)),
            JSONMember(key: "size", value: .array([.measure(size.width), .measure(size.height)])),
            JSONMember(key: "frames", value: .array(frames.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ frame: OCRFrame) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "time", value: .time(frame.time)),
            JSONMember(key: "lines", value: .array(frame.lines.map(output)))
        ]))
    }

    private func output(_ line: RecognisedLine) -> JSONValue {
        let rectangle = line.rectangle

        return .object(JSONObject(members: [
            JSONMember(key: "text", value: .string(line.text)),
            JSONMember(
                key: "rect",
                value: .array([rectangle.x, rectangle.y, rectangle.width, rectangle.height].map(JSONValue.measure))
            )
        ]))
    }
}
