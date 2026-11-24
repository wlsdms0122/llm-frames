//
//  Loudness+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// `{"loudness": "0.1.0", integrated, range, momentaryMax, shortTermMax, truePeak, samplePeak}`, the object
// `loudness --json` prints, each measure as it is held, `null` where the meter gives none.
extension Loudness {
    // MARK: - Property
    package var machineOutput: JSONValue {
        let measure = { (value: Double?) in value.map(JSONValue.number) ?? .null }

        return .object(JSONObject(members: [
            JSONMember(key: "loudness", value: .string(FramesVersion.current)),
            JSONMember(key: "integrated", value: measure(integrated)),
            JSONMember(key: "range", value: measure(range)),
            JSONMember(key: "momentaryMax", value: measure(momentaryMax)),
            JSONMember(key: "shortTermMax", value: measure(shortTermMax)),
            JSONMember(key: "truePeak", value: measure(truePeak)),
            JSONMember(key: "samplePeak", value: measure(samplePeak))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
