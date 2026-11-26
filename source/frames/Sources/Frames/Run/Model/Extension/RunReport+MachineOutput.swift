//
//  RunReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// `{"render": "0.1.0", frames, seconds, cpuSeconds, fps, cores, peakMemory, machine, roles, stages, readAhead,
// waiting, other, media, files, memory}`, the object `render --report` writes (FRAMES-23 Runs). Times are rounded to the
// microsecond, `fps` and `cores` to the millionth.
extension RunReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "render", value: .string(FramesVersion.current)),
            JSONMember(key: "frames", value: Self.count(frames)),
            JSONMember(key: "seconds", value: .time(seconds)),
            JSONMember(key: "cpuSeconds", value: .time(cpuSeconds)),
            JSONMember(key: "fps", value: .measure(framesPerSecond)),
            JSONMember(key: "cores", value: .measure(cores)),
            JSONMember(key: "peakMemory", value: Self.count(peakMemory)),
            JSONMember(key: "machine", value: .object(JSONObject(members: [
                JSONMember(key: "chip", value: .string(machine.chip)),
                JSONMember(key: "cores", value: Self.count(machine.cores)),
                JSONMember(key: "os", value: .string(machine.operatingSystem))
            ]))),
            JSONMember(key: "roles", value: .object(JSONObject(members: [
                JSONMember(key: "decoder", value: .string(roles.decoder)),
                JSONMember(key: "renderer", value: .string(roles.renderer)),
                JSONMember(key: "mixer", value: .string(roles.mixer)),
                JSONMember(key: "encoder", value: .string(roles.encoder))
            ]))),
            JSONMember(key: "stages", value: .object(JSONObject(members: RunStage.allCases.map { stage in
                JSONMember(key: stage.rawValue, value: .time(stages[stage]))
            }))),
            JSONMember(key: "readAhead", value: .object(JSONObject(members: [RunStage.decode, .workingConversion].map {
                JSONMember(key: $0.rawValue, value: .time(readAhead[$0]))
            }))),
            JSONMember(key: "waiting", value: .object(JSONObject(members: [
                JSONMember(key: "encoder", value: .time(waitingOnEncoder)),
                JSONMember(key: "decoder", value: .time(waitingOnDecoder))
            ]))),
            JSONMember(key: "other", value: .time(other)),
            JSONMember(key: "media", value: .array(media.map(Self.written))),
            JSONMember(key: "files", value: .array(files.map(Self.written))),
            JSONMember(key: "memory", value: .object(JSONObject(members: [
                JSONMember(key: "limit", value: Self.count(memory.limit)),
                JSONMember(key: "floor", value: Self.count(memory.floor)),
                JSONMember(key: "peak", value: Self.count(memory.peak)),
                JSONMember(key: "process", value: Self.count(memory.process)),
                JSONMember(key: "uncounted", value: Self.count(memory.uncounted)),
                JSONMember(key: "holders", value: .object(JSONObject(members: memory.holders.map { holder in
                    JSONMember(key: holder.holder.name, value: Self.written(holder))
                })))
            ])))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private static func count(_ value: Int) -> JSONValue {
        .number(Double(value))
    }

    private static func written(_ reading: MediumReading) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "path", value: .string(reading.path)),
            JSONMember(key: "page", value: reading.page.map(count) ?? .null),
            JSONMember(key: "colorSpace", value: reading.conversion.colorSpace.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "conversion", value: .string(reading.conversion.name)),
            JSONMember(key: "device", value: .string(reading.device.name)),
            JSONMember(key: "pixelFormat", value: .string(reading.pixelFormat)),
            JSONMember(key: "framesRead", value: count(reading.framesRead)),
            JSONMember(key: "framesDecoded", value: count(reading.framesDecoded)),
            JSONMember(key: "reopened", value: count(reading.reopened))
        ]))
    }

    private static func written(_ holder: MemoryHolderUsage) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "floor", value: count(holder.floor)),
            JSONMember(key: "peak", value: count(holder.peak)),
            JSONMember(key: "refused", value: count(holder.refused))
        ]))
    }

    private static func written(_ file: FileEncoding) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "path", value: .string(file.path)),
            JSONMember(key: "codec", value: .string(file.codec)),
            JSONMember(key: "hardware", value: .bool(file.usesHardware)),
            JSONMember(key: "device", value: .string(file.device.name))
        ]))
    }
}
